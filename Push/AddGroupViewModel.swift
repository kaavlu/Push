//
//  AddGroupViewModel.swift
//  Push
//
//  Drives the 3-step Add Group flow: name + photo, member picker, review.
//  Mirrors StartPushViewModel's step/advance/goBack shape so the flow feels
//  consistent with Start Push, but stays a separate type since group
//  creation has its own validation (name required, 2-19 invitees).
//

import Combine
import Foundation
import PhotosUI
import SwiftUI

/// One selectable row in the member picker — a friend plus their selection
/// state, presented through the shared `FriendRowCard`.
struct AddGroupMemberRow: Identifiable, Equatable {
    let person: Person
    var id: Person.ID { person.id }

    var friendRow: FriendRowModel {
        FriendRowModel(
            id: person.id,
            friend: FriendPuckData(
                id: person.id,
                name: person.displayName,
                avatarPlaceholder: person.initials,
                profileImageAssetName: person.imageAssetPath,
                activity: "",
                activitySymbolName: "",
                activityDisplayText: "",
                availability: .unavailable,
                venueStatusText: "",
                lastUpdated: ""
            ),
            groupLabel: nil
        )
    }
}

@MainActor
final class AddGroupViewModel: ObservableObject {
    @Published var step: Int = 1
    @Published var groupName: String = ""
    @Published var pickedImage: UIImage?
    @Published var pickedPhotoItem: PhotosPickerItem? {
        didSet { loadPickedImage() }
    }
    @Published var selectedFriendIDs: Set<Person.ID> = []
    @Published var memberSearchText: String = ""
    @Published private(set) var friends: [Person] = []
    @Published private(set) var loadState: LoadState<[Person]> = .idle
    @Published private(set) var isSubmitting = false
    @Published private(set) var actionError: ActionErrorState?

    private let container: AppDataContainer?

    static let stepCount = 3
    static let minMemberSelection = 2
    static let maxMemberSelection = 19

    var canAdvanceStep1: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canAdvanceStep2: Bool {
        (Self.minMemberSelection...Self.maxMemberSelection).contains(selectedFriendIDs.count)
    }

    /// The creator is always an active member on top of the invitees selected here.
    var totalMemberCount: Int { selectedFriendIDs.count + 1 }

    var memberRows: [AddGroupMemberRow] {
        let query = memberSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows = friends.map(AddGroupMemberRow.init)
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.person.displayName.localizedCaseInsensitiveContains(query) }
    }

    var selectedFriends: [Person] {
        friends.filter { selectedFriendIDs.contains($0.id) }
    }

    // `container` defaults via `?? .shared` (not `= .shared`) because default-argument
    // expressions are checked in a nonisolated context even inside a @MainActor
    // initializer; `.shared` is a MainActor-isolated mutable static, so the fallback
    // must live in the (MainActor) initializer body instead.
    init(container: AppDataContainer? = nil) {
        let container = container ?? .shared
        self.container = container
        Task { await load() }
    }

    func load() async {
        guard let container else { return }
        if loadState.value == nil { loadState = .loading }
        do {
            let friendList = try await container.friends.friends()
            friends = friendList
            loadState = .loaded(friendList)
        } catch {
            loadState = .failed(error)
        }
    }

    func toggleSelection(_ id: Person.ID) {
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
    }

    func advance() {
        guard step < Self.stepCount else { return }
        step += 1
    }

    func goBack() {
        guard step > 1 else { return }
        step -= 1
    }

    /// Lets the review step jump straight back to an earlier step's edit affordance.
    func goToStep(_ target: Int) {
        guard (1...Self.stepCount).contains(target) else { return }
        step = target
    }

    /// Creates the group. Failure is retryable — name/photo/selection are left
    /// intact so the user can just tap Create again rather than redo the flow.
    func submit() async -> FriendGroup.ID? {
        guard let container, !isSubmitting else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
            // Photo is session-only by product decision — never uploaded to Storage.
            let groupID = try await container.groups.createGroup(
                name: trimmedName,
                imageAssetPath: nil,
                inviteeIDs: Array(selectedFriendIDs)
            )
            actionError = nil
            return groupID
        } catch {
            actionError = ActionErrorState(message: "Couldn't create the group. Try again.")
            return nil
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    private func loadPickedImage() {
        guard let item = pickedPhotoItem else { return }
        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else { return }
            pickedImage = image
        }
    }
}
