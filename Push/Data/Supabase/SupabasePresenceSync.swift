//
//  SupabasePresenceSync.swift
//  Push
//
//  Live `PresenceSyncing`: latest-draft buffer + Supabase upsert/unpublish
//  with LiveDataStore write-through (Issue #75 / architecture PR5b write path).
//  No movement throttle or heartbeat — those land in Issue #76.
//

import Foundation

/// Coalescing presence writer in front of PostgREST.
///
/// - Failed upserts keep only the **newest** draft.
/// - Successful writes update the session presence cache once.
/// - `shutdown()` drops pending work and ignores further calls.
/// - Never logs coordinates or observation payloads.
final class SupabasePresenceSync: PresenceSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var pending: PresenceStatusDraft?
    private var isShutDown = false
    private var isFlushing = false

    private let userID: Person.ID
    private let store: LiveDataStore
    private let now: @Sendable () -> Date

    init(
        userID: Person.ID,
        store: LiveDataStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.userID = userID
        self.store = store
        self.now = now
    }

    // MARK: - PresenceSyncing

    func upsertCurrentPresence(_ draft: PresenceStatusDraft) async throws {
        guard !isShutDownLocked() else { return }

        // Privacy: unpublished drafts use the unpublish RPC, not a coord upsert.
        if !draft.isPublished {
            clearPending()
            try await performUnpublish()
            return
        }

        guard draft.hasExactCoordinates else {
            // Incomplete publish — do not hit network or mark success.
            return
        }

        setPending(draft)
        try await flushPending()
    }

    func unpublishCurrentPresence() async throws {
        guard !isShutDownLocked() else { return }
        clearPending()
        try await performUnpublish()
    }

    func flushPending() async throws {
        guard !isShutDownLocked() else { return }

        // Single-flight: concurrent callers leave the newest draft in `pending`
        // for the active flusher (or a post-drain re-entry) to pick up.
        guard beginFlush() else { return }

        do {
            while let draft = takePending() {
                guard !isShutDownLocked() else { break }
                guard draft.isPublished, draft.hasExactCoordinates else { continue }

                do {
                    try await performUpsert(draft)
                } catch is CancellationError {
                    requeueIfEmpty(draft)
                    endFlush()
                    throw CancellationError()
                } catch {
                    requeueIfEmpty(draft)
                    endFlush()
                    throw error
                }
            }
        }

        let needsRerun = endFlushAndHasPending()
        if needsRerun {
            try await flushPending()
        }
    }

    func shutdown() {
        lock.lock()
        isShutDown = true
        pending = nil
        lock.unlock()
    }

    // MARK: - Network + store (MainActor hop via LiveDataStore)

    private func performUpsert(_ draft: PresenceStatusDraft) async throws {
        try await store.upsertOwnPresence(userID: userID, draft: draft, now: now())
    }

    private func performUnpublish() async throws {
        try await store.unpublishOwnPresence(userID: userID, now: now())
    }

    // MARK: - Buffer state

    private func isShutDownLocked() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isShutDown
    }

    private func setPending(_ draft: PresenceStatusDraft) {
        lock.lock()
        pending = draft
        lock.unlock()
    }

    private func clearPending() {
        lock.lock()
        pending = nil
        lock.unlock()
    }

    private func takePending() -> PresenceStatusDraft? {
        lock.lock()
        defer { lock.unlock() }
        let value = pending
        pending = nil
        return value
    }

    /// On failure, keep this draft only when a newer one has not already arrived.
    private func requeueIfEmpty(_ draft: PresenceStatusDraft) {
        lock.lock()
        if pending == nil, !isShutDown {
            pending = draft
        }
        lock.unlock()
    }

    private func beginFlush() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if isFlushing { return false }
        isFlushing = true
        return true
    }

    private func endFlush() {
        lock.lock()
        isFlushing = false
        lock.unlock()
    }

    /// Clears the flush flag and reports whether a newer draft arrived mid-flight.
    private func endFlushAndHasPending() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        isFlushing = false
        return pending != nil && !isShutDown
    }

    // MARK: - Test hooks

    /// Newest buffered draft after a failed write (nil when idle or shut down).
    var pendingDraftForTesting: PresenceStatusDraft? {
        lock.lock()
        defer { lock.unlock() }
        return pending
    }

    var isShutDownForTesting: Bool {
        isShutDownLocked()
    }
}
