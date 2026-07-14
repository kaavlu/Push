//
//  SupabaseFriendRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseFriendRepository: FriendRepository {
    private let client: SupabaseClient
    private let currentUserID: String

    init(client: SupabaseClient, currentUserID: String) {
        self.client = client
        self.currentUserID = currentUserID
    }

    func currentUser() async throws -> Person {
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("id", value: currentUserID).limit(1).execute().value
        guard let row = rows.first else { throw SupabaseRepositoryError.notFound }
        return row.person()
    }

    /// Friends = every profile RLS lets us read that isn't us. RLS already scopes
    /// `profiles` reads to self + friends + co-members; excluding self yields friends
    /// (co-members are also friends in the Day-1 seed).
    func friends() async throws -> [Person] {
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().neq("id", value: currentUserID).execute().value
        return rows.map { $0.person() }
    }

    // Presence is out of scope on Day 1 — no live presence data (R1).
    func presenceStatuses() async throws -> [PresenceStatus] { [] }

    // Availability is the user's own row (`profiles_update_self` RLS), so
    // Day-1 writes are supported here unlike the reads-only social graph.
    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        try await client.from("profiles")
            .update(AvailabilityUpdate(availability_choice: rawValue(for: availability)))
            .eq("id", value: currentUserID)
            .execute()
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

private struct AvailabilityUpdate: Encodable {
    let availability_choice: String
}
