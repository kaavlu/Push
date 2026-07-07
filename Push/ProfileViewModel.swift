//
//  ProfileViewModel.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Combine
import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: ProfileData = ProfileViewModel.placeholder
    @Published var displayName: String = ""
    @Published var handle: String = ""
    @Published var initials: String = ""
    @Published private(set) var profileImageAssetName: String?
    @Published private(set) var selectedAvailability: FriendAvailabilityState = .maybeDown
    @Published private(set) var selectedStatusID: String = FriendAvailabilityState.maybeDown.title
    @Published var isPhotoEditorPresented = false
    @Published var connectorAlert: ProfileConnectorAlert?
    @Published private(set) var activityVisibility: [ProfileToggleItem] = []
    @Published private(set) var mapPreferences: [ProfileToggleItem] = []
    @Published private(set) var closeFriends: [ProfileToggleItem] = []
    @Published private(set) var connectors: [ProfileConnector] = []
    @Published private(set) var loadState: LoadState<ProfileData> = .idle

    private let container: AppDataContainer?
    // Holds the active store-change subscription; nil when container is absent.
    private var storeChangeSub: AnyCancellable?
    // Tracks the last revision we loaded so the subscription skips redundant reloads.
    private var lastSeenRevision = 0

    init(container: AppDataContainer = .shared) {
        self.container = container
        Task { await load() }
        // Subscribe after the initial load task so each real mutation triggers a reload.
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    func load() async {
        guard let container else { return }
        loadState = .loading
        do {
            let userProfile = try await container.profile.userProfile()
            let user = try await container.friends.currentUser()
            let statuses = try await container.friends.presenceStatuses()
            let places = try await container.pushes.allPlaces()
            let policies = try await container.sharing.allPolicies()

            let placesByID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
            var presence: VisiblePresence?
            if let status = statuses.first(where: { $0.personID == user.id }) {
                presence = VisiblePresenceBuilder.visiblePresence(
                    of: status, owner: user, viewerID: user.id,
                    sharedGroupIDs: [], policies: policies,
                    placesByID: placesByID, now: Date()
                )
            }
            let data = ProfileContentBuilder.profileData(
                profile: userProfile, person: user, presence: presence
            )
            apply(data: data, userProfile: userProfile)
            loadState = .loaded(data)
            // Stamp the revision so the subscription guard can detect duplicates.
            lastSeenRevision = container.storeRevision
        } catch {
            loadState = .failed(error)
        }
    }

    private func apply(data: ProfileData, userProfile: UserProfile) {
        profile = data
        displayName = data.name
        handle = data.handle
        initials = data.initials
        profileImageAssetName = data.imageAssetName
        selectedAvailability = data.availability
        selectedStatusID = data.availability.title
        activityVisibility = userProfile.activityVisibility
        mapPreferences = userProfile.mapPreferences
        closeFriends = userProfile.closeFriends
        connectors = userProfile.connectors
    }

    private static let placeholder = ProfileData(
        name: "",
        initials: "",
        handle: "",
        imageAssetName: nil,
        availability: .maybeDown,
        activityTitle: "",
        placeTitle: "",
        visibilityNote: "",
        availabilityOptions: []
    )

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
        guard let container else { return }
        Task { try? await container.friends.setCurrentUserAvailability(option.availability) }
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
        guard let container else { return }
        // initials derive from firstName, so only name + handle need to persist.
        Task { try? await container.profile.updateBasics(displayName: name, handle: handle) }
    }

    func beginPhotoEditing() {
        isPhotoEditorPresented = true
    }

    func toggleActivityVisibility(id: String) {
        activityVisibility.toggleItem(id: id)
        persistPrivacy()
    }

    func toggleMapPreference(id: String) {
        mapPreferences.toggleItem(id: id)
        persistPrivacy()
    }

    func toggleCloseFriend(id: String) {
        closeFriends.toggleItem(id: id)
        persistPrivacy()
    }

    /// Shared writer — fires the current toggle arrays to the store after any toggle mutation.
    private func persistPrivacy() {
        guard let container else { return }
        Task {
            try? await container.profile.updatePrivacy(
                activityVisibility: activityVisibility,
                mapPreferences: mapPreferences,
                closeFriends: closeFriends
            )
        }
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
