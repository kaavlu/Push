//
//  SupabaseGroupRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseGroupRepository: GroupRepository {
    private let store: LiveDataStore

    init(store: LiveDataStore) { self.store = store }

    func groups() async throws -> [FriendGroup] {
        let rows = try await store.groups()
        return rows.map { $0.friendGroup() }
    }

    func memberships() async throws -> [GroupMembership] {
        let rows = try await store.memberships()
        return rows.map { $0.membership() }
    }
}
