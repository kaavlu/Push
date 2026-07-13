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

    func person() -> Person {
        Person(id: id, firstName: first_name, imageAssetPath: image_asset_path)
    }

    func userProfile() -> UserProfile {
        UserProfile(
            personID: id,
            handle: handle,
            chosenAvailability: mapAvailability(availability_choice),
            visibilityNote: visibility_note,
            availabilityOptions: [],   // Day-1 UI scaffolding synthesized client-side.
            activityVisibility: [],
            mapPreferences: [],
            closeFriends: [],
            connectors: []
        )
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
        default: return .freeNow
        }
    }
}
