//
//  SupabaseGroupRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseGroupRepository: GroupRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func groups() async throws -> [FriendGroup] {
        let rows: [GroupRow] = try await client.from("groups")
            .select().execute().value
        return rows.map { $0.friendGroup() }
    }

    func memberships() async throws -> [GroupMembership] {
        let rows: [GroupMembershipRow] = try await client.from("group_memberships")
            .select().execute().value
        return rows.map { $0.membership() }
    }
}
