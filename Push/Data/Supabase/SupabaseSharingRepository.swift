//
//  SupabaseSharingRepository.swift
//  Push
//

import Foundation
import Supabase

final class SupabaseSharingRepository: SharingRepository {
    private let store: LiveDataStore

    init(store: LiveDataStore) { self.store = store }

    func allPolicies() async throws -> [SharingPolicy] {
        let rows = try await store.policies()
        return rows.map { $0.policy() }
    }

    func setGlobalDefaults(
        location: SharingPolicy.LocationVisibility,
        activity: SharingPolicy.DetailVisibility,
        availability: SharingPolicy.AvailabilityVisibility
    ) async throws {
        try await store.setGlobalSharingDefaults(
            location: location.rawValue,
            activity: activity.rawValue,
            availability: availability.rawValue
        )
    }
}
