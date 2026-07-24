//
//  ProfileRow.swift
//  Push
//

import Foundation

/// PostgREST row shape for `profiles`. Property names match the table's
/// snake_case columns directly so no `CodingKeys` are needed.
struct ProfileRow: Decodable {
    let id: String
    let first_name: String
    let handle: String
    let image_asset_path: String?
    let availability_choice: String
    let visibility_note: String
    // Per-toggle enabled/disabled overrides keyed by ProfileToggleItem.id. Null
    // (or a missing id) means "use the ProfileScaffolding default" — only the
    // copy-free boolean state is stored server-side.
    let settings_activity_visibility: [String: Bool]?
    let settings_map_preferences: [String: Bool]?
    let settings_close_friends: [String: Bool]?
    /// Null means first-run setup is still required (new accounts after 0019).
    let onboarding_completed_at: String?

    var hasCompletedOnboarding: Bool {
        guard let onboarding_completed_at, !onboarding_completed_at.isEmpty else { return false }
        return true
    }

    func person() -> Person {
        Person(id: id, firstName: first_name, imageAssetPath: image_asset_path)
    }

    func userProfile() -> UserProfile {
        UserProfile(
            personID: id,
            handle: handle,
            chosenAvailability: mapAvailability(availability_choice),
            visibilityNote: visibility_note,
            // Day-1 UI scaffolding: the copy (title/subtitle/icon) is not real
            // social data, so it's synthesized client-side from the same source
            // the mock seed uses (ProfileScaffolding); stored per-id overrides
            // supply the actual enabled/disabled state a user has changed.
            availabilityOptions: ProfileScaffolding.availabilityOptions,
            activityVisibility: Self.applyOverrides(
                ProfileScaffolding.activityVisibility, overrides: settings_activity_visibility
            ),
            mapPreferences: Self.applyOverrides(
                ProfileScaffolding.mapPreferences, overrides: settings_map_preferences
            ),
            closeFriends: Self.applyOverrides(
                ProfileScaffolding.closeFriends, overrides: settings_close_friends
            ),
            connectors: ProfileScaffolding.connectors
        )
    }

    private static func applyOverrides(
        _ defaults: [ProfileToggleItem], overrides: [String: Bool]?
    ) -> [ProfileToggleItem] {
        guard let overrides else { return defaults }
        return defaults.map { item in
            var item = item
            if let isEnabled = overrides[item.id] { item.isEnabled = isEnabled }
            return item
        }
    }

    // FriendAvailabilityState's raw values are camelCase (e.g. "freeNow") while
    // the DB column is snake_case (e.g. "free_now"), so `rawValue:` would
    // silently fail to match any multi-word state. Map explicitly instead.
    private func mapAvailability(_ raw: String) -> FriendAvailabilityState {
        switch raw {
        case "free_now": return .freeNow
        case "free_soon": return .freeSoon
        case "maybe_down": return .maybeDown
        case "busy": return .busy
        case "joinable": return .joinable
        case "driving": return .driving
        case "ghost": return .ghost
        default: return .freeNow
        }
    }
}
