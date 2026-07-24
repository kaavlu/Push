//
//  PresenceRealtimeApplying.swift
//  Push
//
//  Pure Realtime event → cache op mapping (Issue #84).
//  No Supabase types — unit-testable without a live project.
//

import Foundation

/// Wire-level presence change after decoding (or failing to decode) a Realtime payload.
enum PresenceRealtimeWireEvent: Equatable {
    case insert(CurrentPresenceRow?)
    case update(new: CurrentPresenceRow?, oldUserID: String?)
    case delete(oldUserID: String?)
}

/// Operation to apply against `LiveDataStore` presence cache.
enum PresenceRealtimeOp: Equatable {
    case upsert(CurrentPresenceRow)
    case remove(userID: String)
    case reconcileHint
}

/// Maps wire events to cache ops. Self events return `nil` (own write-through owns self).
enum PresenceRealtimeApplying {

    /// - Returns: `nil` to ignore (self / no-op); otherwise an op for the bridge.
    static func operation(
        from event: PresenceRealtimeWireEvent,
        currentUserID: String,
        now: Date = Date()
    ) -> PresenceRealtimeOp? {
        switch event {
        case .insert(let row):
            return insertOp(row: row, currentUserID: currentUserID, now: now)
        case .update(let new, let oldUserID):
            return updateOp(new: new, oldUserID: oldUserID, currentUserID: currentUserID, now: now)
        case .delete(let oldUserID):
            return deleteOp(oldUserID: oldUserID, currentUserID: currentUserID)
        }
    }

    // MARK: - Per-event

    private static func insertOp(
        row: CurrentPresenceRow?,
        currentUserID: String,
        now: Date
    ) -> PresenceRealtimeOp? {
        guard let row else { return nil }
        if isSelf(row.user_id, currentUserID) { return nil }
        if isFriendVisibleRemote(row, now: now) {
            return .upsert(row)
        }
        return .remove(userID: row.user_id)
    }

    private static func updateOp(
        new: CurrentPresenceRow?,
        oldUserID: String?,
        currentUserID: String,
        now: Date
    ) -> PresenceRealtimeOp? {
        if let new {
            if isSelf(new.user_id, currentUserID) { return nil }
            if isFriendVisibleRemote(new, now: now) {
                return .upsert(new)
            }
            return .remove(userID: new.user_id)
        }
        if let oldUserID {
            if isSelf(oldUserID, currentUserID) { return nil }
            // Optimistic remove when new row is not decodeable (RLS / unpublish gap).
            return .remove(userID: oldUserID)
        }
        return .reconcileHint
    }

    private static func deleteOp(
        oldUserID: String?,
        currentUserID: String
    ) -> PresenceRealtimeOp? {
        guard let oldUserID else { return .reconcileHint }
        if isSelf(oldUserID, currentUserID) { return nil }
        return .remove(userID: oldUserID)
    }

    // MARK: - Visibility

    /// Remote friend-visible for Realtime apply (before SharingPolicy projection).
    static func isFriendVisibleRemote(_ row: CurrentPresenceRow, now: Date) -> Bool {
        guard row.is_published else { return false }
        if let expiresRaw = row.expires_at,
           let expires = PushDateFormatting.parse(expiresRaw),
           expires <= now {
            return false
        }
        // Align with domain mapping: legacy ghost availability is not effectively published.
        if let status = row.presenceStatus() {
            return status.isEffectivelyPublished
                && status.freshnessState(at: now).isFriendVisible
        }
        // Malformed for domain mapping but still published — treat as not safe to upsert.
        return false
    }

    private static func isSelf(_ userID: String, _ currentUserID: String) -> Bool {
        userID.caseInsensitiveCompare(currentUserID) == .orderedSame
    }
}
