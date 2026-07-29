//
//  CreatePostViewModel+Presentation.swift
//  Push
//
//  Derived view state for the Create Post flow: chooser visibility, submit
//  gating, and screen copy. No mutation and no repository access.
//

import Foundation

@MainActor
extension CreatePostViewModel {

    var visibleChooserItems: [CreatePostHistoryItem] {
        switch selectedSegment {
        case .existingMoments: return existingMoments
        case .pastPushes: return pastPushes
        }
    }

    var segmentItems: [PushIvorySegmentedItem] {
        CreatePostHubSegment.allCases.map { segment in
            let count: Int
            switch segment {
            case .existingMoments: count = existingMoments.count
            case .pastPushes: count = pastPushes.count
            }
            return PushIvorySegmentedItem(id: segment.rawValue, title: segment.title, count: count)
        }
    }

    var selectedSegmentID: String {
        get { selectedSegment.rawValue }
        set { selectedSegment = CreatePostHubSegment(rawValue: newValue) ?? .existingMoments }
    }

    var filteredFriends: [PushRecipientItem] {
        let query = friendSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableFriends }
        return availableFriends.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var selectedFriends: [PushRecipientItem] {
        availableFriends.filter { selectedFriendIDs.contains($0.id) }
    }

    /// Scratch friend step allows solo (empty selection).
    var canContinueFromFriends: Bool {
        screen == .selectFriends && phase == .composing
    }

    var canSubmit: Bool {
        !items.isEmpty && phase == .composing && !isLoadingPicker && screen == .compose
    }

    var canAddMore: Bool {
        items.count < maxSelection && phase == .composing && screen == .compose
    }

    var remainingSlots: Int {
        max(0, maxSelection - items.count)
    }

    var focusedItem: AddYoursDraftItem? {
        guard items.indices.contains(focusedIndex) else { return nil }
        return items[focusedIndex]
    }

    /// Existing moment edit path — different primary copy from create.
    var isEditingExistingMoment: Bool {
        if case .existingMoment = source { return true }
        return false
    }

    /// Scratch path uses friend selection before compose.
    var usesFriendSelection: Bool {
        if case .scratch = source { return true }
        return false
    }

    /// Friend picker opened from compose “With · Edit” (any source).
    var isEditingPeopleFromCompose: Bool {
        friendPickerEntry == .editFromCompose
    }

    var friendPickerPrimaryTitle: String {
        isEditingPeopleFromCompose
            ? CreatePostCopy.selectFriendsDone
            : CreatePostCopy.selectFriendsNext
    }

    /// Compose always shows the With section so Edit can add people.
    var showsPeopleSection: Bool {
        screen == .compose && phase != .success
    }

    var canEditPeople: Bool {
        phase == .composing && screen == .compose
    }

    var primaryButtonTitle: String {
        if phase == .submitting {
            return isEditingExistingMoment
                ? CreatePostCopy.editSubmittingAction
                : CreatePostCopy.submittingAction
        }
        return isEditingExistingMoment
            ? CreatePostCopy.editPrimaryAction
            : CreatePostCopy.primaryAction
    }

    var isPrimaryLoading: Bool {
        phase == .submitting
    }

    var composeTitle: String {
        if case .existingMoment = source {
            return CreatePostCopy.composeEditTitle
        }
        return CreatePostCopy.composeTitle
    }

    var composeSubtitle: String {
        switch source {
        case .scratch:
            return CreatePostCopy.composeFromScratchSubtitle
        case .existingMoment:
            return CreatePostCopy.composeFromExistingSubtitle
        case .pastPush:
            return CreatePostCopy.composeFromPastSubtitle
        }
    }

    var showsParticipants: Bool {
        !memberPersonRows.isEmpty
    }
}
