//
//  ProfileViewModel.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import Combine
import Foundation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var profile: ProfileData = ProfileViewModel.placeholder
    @Published var displayName: String = ""
    @Published var handle: String = ""
    @Published var initials: String = ""
    @Published private(set) var profileImageAssetName: String?
    @Published private(set) var selectedAvailability: FriendAvailabilityState = .maybeDown
    @Published private(set) var selectedStatusID: String = FriendAvailabilityState.maybeDown.title
    /// Orthogonal Ghost (publish off). Independent of `selectedAvailability` (Busy+Ghost).
    @Published private(set) var isGhostModeEnabled = false
    @Published var isPhotoEditorPresented = false
    @Published var isPhotoPickerPresented = false
    @Published var photoPickerItem: PhotosPickerItem?
    @Published private(set) var isPhotoBusy = false
    @Published var photoErrorMessage: String?
    @Published var connectorAlert: ProfileConnectorAlert?
    @Published private(set) var activityVisibility: [ProfileToggleItem] = []
    @Published private(set) var mapPreferences: [ProfileToggleItem] = []
    @Published private(set) var closeFriends: [ProfileToggleItem] = []
    @Published private(set) var connectors: [ProfileConnector] = []
    @Published private(set) var loadState: LoadState<ProfileData> = .idle
    @Published private(set) var actionError: ActionErrorState?

    private let container: AppDataContainer?
    // Holds the active store-change subscription; nil when container is absent.
    private var storeChangeSub: AnyCancellable?
    // Tracks the last revision we loaded so the subscription skips redundant reloads.
    private var lastSeenRevision = 0
    private var pendingAvailability: FriendAvailabilityState?
    private var pendingPublishEnabled: Bool?
    private var statusRollback: (availability: FriendAvailabilityState, statusID: String, ghost: Bool)?

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
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
        if loadState.value == nil { loadState = .loading }
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
            // Ghost from session publish flag, then self presence, then legacy availability.
            if let session = container.locationSession {
                isGhostModeEnabled = !session.state.isPresencePublishingEnabled
            } else if let selfStatus = statuses.first(where: { $0.personID == user.id }) {
                isGhostModeEnabled = !selfStatus.isEffectivelyPublished
            } else {
                isGhostModeEnabled = userProfile.chosenAvailability == .ghost
            }
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
        // A store reload is authoritative: resets typed initials, which stay UI-only.
        initials = data.initials
        profileImageAssetName = data.imageAssetName
        // Social availability only — never surface legacy `.ghost` as the chip.
        let social = data.availability == .ghost ? FriendAvailabilityState.maybeDown : data.availability
        selectedAvailability = social
        selectedStatusID = isGhostModeEnabled
            ? ProfileStatusOption.ghostMode.id
            : social.title
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

    var legalDestinations: [LegalDestination] {
        LegalDestinations.all
    }

    var visibilitySummary: String {
        if isGhostModeEnabled {
            return "Hidden from friends' map and social context until you turn Ghost Mode off."
        }

        return profile.visibilityNote
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

    // Falls back to synthesizing the real availability rather than `.ghostMode`:
    // live profiles can carry a `chosenAvailability` outside the 3 quick-pick
    // options (e.g. joinable, driving), and those users are not hidden.
    private var selectedStatusOption: ProfileStatusOption {
        if isGhostModeEnabled { return .ghostMode }
        return statusOptions.first { $0.id == selectedStatusID }
            ?? .availability(ProfileAvailabilityOption(availability: selectedAvailability, subtitle: ""))
    }

    func isSelected(_ option: ProfileAvailabilityOption) -> Bool {
        !isGhostModeEnabled && selectedAvailability == option.availability
    }

    func isSelected(_ option: ProfileStatusOption) -> Bool {
        switch option {
        case .ghostMode:
            return isGhostModeEnabled
        case .availability(let availabilityOption):
            // Allow Busy + Ghost: availability can stay selected while Ghost is on.
            return selectedAvailability == availabilityOption.availability
        }
    }

    func select(_ option: ProfileAvailabilityOption) {
        commitAvailability(option.availability)
    }

    func select(_ option: ProfileStatusOption) {
        switch option {
        case .ghostMode:
            // Toggle orthogonal publish flag — never write availability `.ghost`.
            commitGhostEnabled(!isGhostModeEnabled)
        case .availability(let availabilityOption):
            commitAvailability(availabilityOption.availability)
        }
    }

    func dismissActionError() {
        actionError = nil
        pendingAvailability = nil
        pendingPublishEnabled = nil
        statusRollback = nil
    }

    func retryActionError() {
        if let pendingAvailability {
            Task { await persistAvailability(pendingAvailability) }
            return
        }
        if let pendingPublishEnabled {
            Task { await persistGhostEnabled(pendingPublishEnabled) }
        }
    }

    private func commitAvailability(_ availability: FriendAvailabilityState) {
        let social = availability == .ghost ? FriendAvailabilityState.maybeDown : availability
        statusRollback = (selectedAvailability, selectedStatusID, isGhostModeEnabled)
        selectedAvailability = social
        if !isGhostModeEnabled {
            selectedStatusID = social.title
        }
        pendingAvailability = social
        pendingPublishEnabled = nil
        actionError = nil
        Task { await persistAvailability(social) }
    }

    private func commitGhostEnabled(_ ghostOn: Bool) {
        statusRollback = (selectedAvailability, selectedStatusID, isGhostModeEnabled)
        isGhostModeEnabled = ghostOn
        selectedStatusID = ghostOn
            ? ProfileStatusOption.ghostMode.id
            : selectedAvailability.title
        pendingPublishEnabled = !ghostOn
        pendingAvailability = nil
        actionError = nil
        Task { await persistGhostEnabled(!ghostOn) }
    }

    private func persistAvailability(_ availability: FriendAvailabilityState) async {
        guard let container else { return }
        do {
            try await container.friends.setCurrentUserAvailability(availability)
            pendingAvailability = nil
            statusRollback = nil
            actionError = nil
            lastSeenRevision = container.storeRevision
        } catch {
            rollBackStatus()
            pendingAvailability = availability
            actionError = ActionErrorState(message: ProfileMutationCopy.availabilityFailed)
        }
    }

    private func persistGhostEnabled(_ publishEnabled: Bool) async {
        guard let container else { return }
        // Best-effort: local Ghost state wins even if network unpublish fails
        // (server hardExpire is the offline safety net — design §2.9.1).
        await container.locationSession?.setPresencePublishingEnabled(publishEnabled)
        pendingPublishEnabled = nil
        statusRollback = nil
        actionError = nil
        isGhostModeEnabled = !publishEnabled
        lastSeenRevision = container.storeRevision
    }

    private func rollBackStatus() {
        guard let statusRollback else { return }
        selectedAvailability = statusRollback.availability
        selectedStatusID = statusRollback.statusID
        isGhostModeEnabled = statusRollback.ghost
    }

    func setProfileBasics(name: String, handle: String, initials: String) {
        displayName = name
        self.handle = handle
        self.initials = initials
        guard let container else { return }
        // initials derive from firstName, so only name + handle need to persist.
        Task { try? await container.profile.updateBasics(displayName: name, handle: handle) }
    }

    var hasProfilePhoto: Bool {
        guard let profileImageAssetName, !profileImageAssetName.isEmpty else { return false }
        return true
    }

    func beginPhotoEditing() {
        guard !isPhotoBusy else { return }
        isPhotoEditorPresented = true
    }

    func choosePhotoFromLibrary() {
        isPhotoEditorPresented = false
        isPhotoPickerPresented = true
    }

    func handlePhotoPickerItemChange(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task { await applyPickedPhoto(item) }
    }

    func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard !isPhotoBusy else { return }
        isPhotoBusy = true
        photoErrorMessage = nil
        defer {
            isPhotoBusy = false
            photoPickerItem = nil
        }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self) else {
                photoErrorMessage = "Couldn't read that photo. Try another one."
                return
            }
            guard let jpeg = ProfilePhotoProcessor.jpegData(from: raw) else {
                photoErrorMessage = "Couldn't process that photo. Try another one."
                return
            }
            guard let container else { return }
            try await container.profile.updateProfilePhoto(jpegData: jpeg)
            await load()
        } catch {
            photoErrorMessage = "Couldn't save your photo. Check your connection and try again."
        }
    }

    func removeProfilePhoto() {
        guard !isPhotoBusy else { return }
        isPhotoEditorPresented = false
        Task { await performRemoveProfilePhoto() }
    }

    private func performRemoveProfilePhoto() async {
        guard let container else { return }
        isPhotoBusy = true
        photoErrorMessage = nil
        defer { isPhotoBusy = false }
        do {
            try await container.profile.removeProfilePhoto()
            await load()
        } catch {
            photoErrorMessage = "Couldn't remove your photo. Try again."
        }
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

enum ProfileMutationCopy {
    static let availabilityFailed = "Couldn't update your status. Check your connection and try again."
}
