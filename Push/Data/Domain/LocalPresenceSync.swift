//
//  LocalPresenceSync.swift
//  Push
//
//  Mock PresenceSyncing: write-through to InMemoryDatabase so Ghost unpublish
//  and location upserts affect friend-visible presence without network.
//

import Foundation

/// In-process presence writer for mock containers (Issue #76 Ghost/mock parity).
final class LocalPresenceSync: PresenceSyncing, @unchecked Sendable {
    private let lock = NSLock()
    private var isShutDown = false
    private let database: InMemoryDatabase
    private let now: @Sendable () -> Date

    init(
        database: InMemoryDatabase,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.database = database
        self.now = now
    }

    func upsertCurrentPresence(_ draft: PresenceStatusDraft) async throws {
        guard !isShutDownLocked() else { return }
        if !draft.isPublished {
            await MainActor.run {
                self.database.unpublishOwnPresence(at: self.now())
            }
            return
        }
        guard draft.hasExactCoordinates else { return }
        await MainActor.run {
            self.database.upsertOwnPresence(draft, at: self.now())
        }
    }

    func unpublishCurrentPresence() async throws {
        guard !isShutDownLocked() else { return }
        await MainActor.run {
            self.database.unpublishOwnPresence(at: self.now())
        }
    }

    func flushPending() async throws {
        // Mock writes are synchronous — nothing to flush.
    }

    func shutdown() {
        lock.lock()
        isShutDown = true
        lock.unlock()
    }

    private func isShutDownLocked() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isShutDown
    }
}
