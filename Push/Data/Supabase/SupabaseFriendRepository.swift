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

    /// Friends = accepted friendships (plus co-members still visible under group
    /// RLS). Pending counterparty profiles are visible for Alerts but are not friends.
    func friends() async throws -> [Person] {
        let friendships = try await store.friendships()
        let accepted = Set(
            friendships
                .filter { $0.isAccepted && $0.involves(currentUserID) }
                .compactMap { $0.otherUserID(relativeTo: currentUserID)?.lowercased() }
        )
        let pendingOnly = Set(
            friendships
                .filter { $0.isPending && $0.involves(currentUserID) }
                .compactMap { $0.otherUserID(relativeTo: currentUserID)?.lowercased() }
        )
        return try await store.profiles()
            .filter { $0.id.caseInsensitiveCompare(currentUserID) != .orderedSame }
            .filter { row in
                let id = row.id.lowercased()
                if accepted.contains(id) { return true }
                if pendingOnly.contains(id) { return false }
                return true
            }
            .map { $0.person() }
    }

    // Presence is out of scope on Day 1 — no live presence data (R1).
    func presenceStatuses() async throws -> [PresenceStatus] { [] }

    // Availability is the user's own row (`profiles_update_self` RLS), so
    // Day-1 writes are supported here unlike the reads-only social graph.
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        try await store.updateAvailability(userID: currentUserID, rawValue: rawValue(for: availability))
    }

    func searchPeople(query: String) async throws -> [PersonSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let hits = try await store.searchProfiles(query: trimmed)
        let friendships = try await store.friendships()
        return hits
            .filter { $0.id.caseInsensitiveCompare(currentUserID) != .orderedSame }
            .map { row in
                PersonSearchResult(
                    person: row.person(),
                    handle: row.handle,
                    relation: relation(to: row.id, friendships: friendships)
                )
            }
    }

    func sendFriendRequest(to personID: Person.ID) async throws {
        try await store.sendFriendRequest(targetUserID: personID)
    }

    func removeFriend(_ personID: Person.ID) async throws {
        try await store.removeFriend(targetUserID: personID)
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
        case .ghost: return "ghost"
        }
    }

    private func relation(to personID: String, friendships: [FriendshipRow]) -> FriendshipRelation {
        let row = friendships.first {
            $0.involves(currentUserID) && $0.involves(personID)
        }
        guard let row else { return .none }
        if row.isAccepted { return .friends }
        if row.isPending {
            if row.isRequester(currentUserID) {
                return .outgoingPending(requestID: row.id)
            }
            return .incomingPending(requestID: row.id)
        }
        return .none
    }
}
