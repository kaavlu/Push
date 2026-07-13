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

    func setCurrentUserAvailability(_ availability: FriendAvailabilityState) async throws {
        throw SupabaseRepositoryError.writeNotSupported
    }
}
