//
//  ProfileViewModel.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Combine
import Foundation

final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: ProfileData
    @Published var displayName: String
    @Published var handle: String
    @Published var initials: String
    @Published private(set) var profileImageAssetName: String?
    @Published private(set) var selectedAvailability: FriendAvailabilityState
    @Published private(set) var selectedStatusID: String
    @Published var isPhotoEditorPresented = false
    @Published var connectorAlert: ProfileConnectorAlert?
    @Published private(set) var activityVisibility: [ProfileToggleItem]
    @Published private(set) var mapPreferences: [ProfileToggleItem]
    @Published private(set) var closeFriends: [ProfileToggleItem]
    let connectors: [ProfileConnector]

    init(profile: ProfileData = ProfileMockData.currentUser) {
        self.profile = profile
        self.displayName = profile.name
        self.handle = profile.handle
        self.initials = profile.initials
        self.profileImageAssetName = profile.imageAssetName
        self.selectedAvailability = profile.availability
        self.selectedStatusID = profile.availability.title
        self.activityVisibility = ProfileMockData.activityVisibility
        self.mapPreferences = ProfileMockData.mapPreferences
        self.closeFriends = ProfileMockData.closeFriends
        self.connectors = ProfileMockData.connectors
    }

    var settingsRoutes: [ProfileRoute] {
        ProfileRoute.allCases.filter { $0.section == .settings }
    }

    var privacyRoutes: [ProfileRoute] {
        ProfileRoute.allCases.filter { $0.section == .privacy }
    }

    var visibilitySummary: String {
        if isGhostModeEnabled {
            return "Hidden from friends' map and social context until you turn Ghost Mode off."
        }

        return profile.visibilityNote
    }

    var isGhostModeEnabled: Bool {
        selectedStatusID == ProfileStatusOption.ghostMode.id
    }

    var statusOptions: [ProfileStatusOption] {
        [.ghostMode] + profile.availabilityOptions.map(ProfileStatusOption.availability)
    }

    var selectedStatusTitle: String {
        selectedStatusOption.title
    }

    var selectedStatusSymbolName: String {
        selectedStatusOption.symbolName
    }

    private var selectedStatusOption: ProfileStatusOption {
        statusOptions.first { $0.id == selectedStatusID } ?? .ghostMode
    }

    func isSelected(_ option: ProfileAvailabilityOption) -> Bool {
        selectedStatusID == ProfileStatusOption.availability(option).id
    }

    func isSelected(_ option: ProfileStatusOption) -> Bool {
        selectedStatusID == option.id
    }

    func select(_ option: ProfileAvailabilityOption) {
        selectedAvailability = option.availability
        selectedStatusID = ProfileStatusOption.availability(option).id
    }

    func select(_ option: ProfileStatusOption) {
        selectedStatusID = option.id

        if case .availability(let availabilityOption) = option {
            selectedAvailability = availabilityOption.availability
        }
    }

    func setProfileBasics(name: String, handle: String, initials: String) {
        displayName = name
        self.handle = handle
        self.initials = initials
    }

    func beginPhotoEditing() {
        isPhotoEditorPresented = true
    }

    func toggleActivityVisibility(id: String) {
        activityVisibility.toggleItem(id: id)
    }

    func toggleMapPreference(id: String) {
        mapPreferences.toggleItem(id: id)
    }

    func toggleCloseFriend(id: String) {
        closeFriends.toggleItem(id: id)
    }

    func connect(_ connector: ProfileConnector) {
        connectorAlert = ProfileConnectorAlert(
            id: connector.id,
            title: connector.alertTitle,
            message: connector.alertMessage
        )
    }
}

private extension Array where Element == ProfileToggleItem {
    mutating func toggleItem(id: String) {
        guard let index = firstIndex(where: { $0.id == id }) else {
            return
        }

        self[index].isEnabled.toggle()
    }
}
