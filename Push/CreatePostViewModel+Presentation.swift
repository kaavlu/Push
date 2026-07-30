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
        guard phase == .composing, !isLoadingPicker, screen == .compose else { return false }
        if isEditingExistingMoment {
            // Preview seam has no repository — keep the old "any media" gate.
            guard isRepositoryBacked else { return !items.isEmpty }
            // Need a loaded detail and at least one permitted change (or pending
            // media removals). Empty album is allowed — save soft-deletes media.
            guard editDetail != nil, !isEditSurfaceDenied else { return false }
            return hasPendingEditChanges
        }
        return !items.isEmpty
    }

    /// Local draft differs from the loaded baseline on a field the viewer may edit.
    var hasPendingEditChanges: Bool {
        guard let caps = editDetail?.capabilities else { return false }
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if caps.canEditMetadata,
           title != baselineTitle || location != baselineLocation {
            return true
        }
        if caps.canEditTags {
            let desired = Set(memberPersonRows.map(\.id))
            if desired != Set(baselineTagIDs) { return true }
        }
        let currentIDs = items.compactMap(\.existingMediaID)
        if currentIDs != baselineMediaIDs {
            // Membership change (delete) or order change.
            if Set(currentIDs) != Set(baselineMediaIDs) { return true }
            if caps.canReorderMedia { return true }
        }
        return false
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
        guard phase == .composing, screen == .compose else { return false }
        if isEditingExistingMoment, isRepositoryBacked {
            return editDetail?.capabilities.canEditTags == true
        }
        return true
    }

    /// Title / location fields — creator only on an existing Moment.
    var canEditMetadataFields: Bool {
        guard phase == .composing, screen == .compose else { return false }
        if isEditingExistingMoment, isRepositoryBacked {
            return editDetail?.capabilities.canEditMetadata == true
        }
        return true
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

    /// Hide the primary save CTA when the only remaining actions are overflow
    /// destructive ones (leave / delete).
    var showsPrimarySaveAction: Bool {
        if isEditingExistingMoment, isRepositoryBacked {
            guard let detail = editDetail else { return false }
            let caps = detail.capabilities
            return caps.canEditMetadata
                || caps.canEditTags
                || caps.canReorderMedia
                || detail.media.contains { caps.canDeleteMedia($0) }
        }
        return true
    }
}
