//
//  SupabaseFriendRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseFriendRepository: FriendRepository {
    private let store: LiveDataStore
    private let currentUserID: String

    init(store: LiveDataStore, currentUserID: String) {
        self.store = store
        self.currentUserID = currentUserID
    }

    func currentUser() async throws -> Person {
        try await store.profile(userID: currentUserID).person()
    }

    /// Friends = every profile RLS lets us read that isn't us. RLS already scopes
    /// `profiles` reads to self + friends + co-members; excluding self yields friends
    /// (co-members are also friends in the Day-1 seed).
    func friends() async throws -> [Person] {
        try await store.profiles()
            .filter { $0.id.caseInsensitiveCompare(currentUserID) != .orderedSame }
            .map { $0.person() }
    }

    // Presence is out of scope on Day 1 — no live presence data (R1).
    func presenceStatuses() async throws -> [PresenceStatus] { [] }

    // Availability is the user's own row (`profiles_update_self` RLS), so
    // Day-1 writes are supported here unlike the reads-only social graph.
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        try await store.updateAvailability(userID: currentUserID, rawValue: rawValue(for: availability))
    }

    // Mirror image of `ProfileRow.mapAvailability` — Swift's raw values are
    // camelCase while the DB column is snake_case, so this needs an explicit map.
    private func rawValue(for availability: FriendAvailabilityState) -> String {
        switch availability {
        case .freeNow: return "free_now"
        case .freeSoon: return "free_soon"
        case .maybeDown: return "maybe_down"
        case .busy: return "busy"
        case .joinable: return "joinable"
        case .driving: return "driving"
        case .unavailable: return "unavailable"
        }
    }
}
