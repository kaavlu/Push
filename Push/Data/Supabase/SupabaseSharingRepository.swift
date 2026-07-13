//
//  SupabaseSharingRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseSharingRepository: SharingRepository {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func allPolicies() async throws -> [SharingPolicy] {
        let rows: [SharingPolicyRow] = try await client.from("sharing_policies")
            .select().execute().value
        return rows.map { $0.policy() }
    }
}
