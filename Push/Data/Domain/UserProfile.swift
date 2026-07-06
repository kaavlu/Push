//
//  UserProfile.swift
//  Push
//

import Foundation

/// Current-user profile and settings. Privacy toggles here are backed by the
/// user's SharingPolicy rows where the two overlap.
struct UserProfile: Codable, Equatable {
    let personID: Person.ID
    let handle: String
    /// The status the user picked on the profile screen (Set Status cards).
    let chosenAvailability: FriendAvailabilityState
    let visibilityNote: String
    let availabilityOptions: [ProfileAvailabilityOption]
    let activityVisibility: [ProfileToggleItem]
    let mapPreferences: [ProfileToggleItem]
    let closeFriends: [ProfileToggleItem]
    let connectors: [ProfileConnector]
}
