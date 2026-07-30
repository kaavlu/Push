//
//  CreatePostViewModel+Edit.swift
//  Push
//
//  Moments S9: repository-backed edit for an existing Moment. Loads
//  `MomentDetail` (capabilities are server-shaped), diffs the draft against
//  that baseline, and persists metadata / tags / reorder / media soft-delete.
//  Creator delete and non-creator self-remove are separate confirmed actions.
//

import Foundation

@MainActor
extension CreatePostViewModel {

    /// True while edit is loading/failed before a usable detail is available.
    var isEditSurfaceLoading: Bool {
        isEditingExistingMoment && editDetail == nil && {
            switch editLoadState {
            case .idle, .loading: return true
            case .failed, .loaded: return false
            }
        }()
    }

    var isEditSurfaceFailed: Bool {
        isEditingExistingMoment && editDetail == nil && {
            if case .failed = editLoadState { return true }
            return false
        }()
    }

    /// Loaded but the viewer can no longer open any edit affordance (stale card).
    var isEditSurfaceDenied: Bool {
        guard isEditingExistingMoment, let detail = editDetail else { return false }
        let caps = detail.capabilities
        return !caps.canEditMetadata
            && !caps.canEditTags
            && !caps.canReorderMedia
            && !caps.canDeleteMoment
            && !caps.canSelfRemoveTag
            && !detail.media.contains { caps.canDeleteMedia($0) }
    }

    var editContentPhase: SurfaceContentPhase {
        if editDetail != nil { return .content }
        switch editLoadState {
        case .idle, .loading: return .loading
        case .failed: return .failed
        case .loaded: return .content
        }
    }

    var canDeleteFocusedMedia: Bool {
        guard phase == .composing, let item = focusedItem else { return false }
        return canDeleteDraftMedia(item)
    }

    var canReorderEditMedia: Bool {
        guard phase == .composing else { return false }
        guard isEditingExistingMoment, isRepositoryBacked else { return true }
        return editDetail?.capabilities.canReorderMedia == true
    }

    /// Existing-Moment strip never appends — that is Add Yours.
    var canAddMoreOnCompose: Bool {
        guard !(isEditingExistingMoment && isRepositoryBacked) else { return false }
        return canAddMore
    }

    var showsDeleteMomentAction: Bool {
        isRepositoryBacked
            && editDetail?.capabilities.canDeleteMoment == true
            && phase == .composing
    }

    var showsLeaveMomentAction: Bool {
        isRepositoryBacked
            && editDetail?.capabilities.canSelfRemoveTag == true
            && phase == .composing
    }

    var showsEditOverflowMenu: Bool {
        showsDeleteMomentAction || showsLeaveMomentAction
    }

    // MARK: - Load

    /// Server detail is the edit source of truth (architecture §6.4). Carousel /
    /// hub rows are launch hints only — same rule as Add Yours.
    func loadEditDetail(momentID: Moment.ID) async {
        guard let momentsRepo else {
            editLoadState = .failed(MomentRepositoryError.notFound)
            return
        }
        if editDetail == nil { editLoadState = .loading }
        do {
            let detail = try await momentsRepo.moment(id: momentID)
            applyEditDetail(detail)
            editLoadState = .loaded(())
        } catch {
            if editDetail == nil {
                editLoadState = .failed(error)
            }
        }
    }

    func retryEditLoad() async {
        guard case .existingMoment(let id) = source else { return }
        await loadEditDetail(momentID: id)
    }

    /// Replaces the compose draft with the live album + capabilities.
    func applyEditDetail(_ detail: MomentDetail) {
        editDetail = detail
        baselineTitle = detail.moment.title
        baselineLocation = detail.moment.locationText
        baselineTagIDs = detail.members.map(\.personID)
        baselineMediaIDs = detail.media.map(\.id)
        titleText = detail.moment.title
        locationText = detail.moment.locationText

        let participants = detail.members.map { member -> FeedMediaParticipant in
            if let person = peopleByID[member.personID] {
                return FeedMediaParticipant(
                    id: person.id,
                    displayName: person.displayName,
                    imageAssetPath: person.imageAssetPath
                )
            }
            // Keep the id even when the people cache is still empty.
            return FeedMediaParticipant(
                id: member.personID, displayName: member.personID, imageAssetPath: nil
            )
        }
        displayParticipants = participants
        memberPersonRows = CreatePostHistoryItem(
            id: detail.id, title: "", dateLabel: "", locationTitle: "",
            participants: participants, contributors: [], mediaItems: [],
            style: .pastPush
        ).memberPersonRows
        mergeParticipantsIntoAvailableFriends(participants)
        selectedFriendIDs = Set(participants.map(\.id))
        items = detail.media.map(Self.draft(from:))
        focusedIndex = AddYoursSelection.clampedIndex(0, itemCount: items.count)
        actionError = nil
    }

    // MARK: - Media gates

    func canDeleteDraftMedia(_ item: AddYoursDraftItem) -> Bool {
        guard phase == .composing else { return false }
        guard isEditingExistingMoment, isRepositoryBacked else { return true }
        guard let mediaID = item.existingMediaID else { return true }
        guard let detail = editDetail else { return false }
        guard let media = detail.media.first(where: { $0.id == mediaID }) else { return true }
        return detail.capabilities.canDeleteMedia(media)
    }

    // MARK: - Save

    /// Diff-based edit commit. Failures leave the draft for Retry.
    func saveExistingMomentEdits() async {
        guard isEditingExistingMoment, let momentsRepo, let detail = editDetail else {
            actionError = ActionErrorState(message: CreatePostEditCopy.generic)
            return
        }
        guard phase == .composing else { return }

        let momentID = detail.id
        let caps = detail.capabilities
        phase = .submitting
        actionError = nil

        do {
            try await applyMediaDiffs(
                momentID: momentID, caps: caps, moments: momentsRepo
            )
            // Last media soft-delete may have removed the whole Moment.
            let albumEmpty = items.isEmpty
            let momentGone = albumEmpty
                ? true
                : await isMomentGone(momentID, moments: momentsRepo)
            if momentGone {
                await finishEditDismissing()
                return
            }
            try await applyMetadataAndTagDiffs(
                momentID: momentID, caps: caps, moments: momentsRepo
            )
            await finishEditSaved(momentID: momentID)
        } catch {
            phase = .composing
            let message = CreatePostEditCopy.message(for: error)
            actionError = ActionErrorState(message: message)
            // Conflict: the active media set no longer matches. Reload so the
            // next retry diffs against the server order (not a corrupted local
            // strip). Other failures keep the draft so Retry can resubmit it.
            if (error as? MomentRepositoryError) == .conflict {
                await loadEditDetail(momentID: momentID)
                // applyEditDetail clears actionError — restore the banner.
                actionError = ActionErrorState(message: message)
            }
        }
    }

    private func isMomentGone(_ momentID: Moment.ID, moments: MomentRepository) async -> Bool {
        do {
            _ = try await moments.moment(id: momentID)
            return false
        } catch {
            return true
        }
    }

    // MARK: - Destructive

    func deleteMoment() async {
        guard showsDeleteMomentAction, let momentsRepo, let detail = editDetail else { return }
        phase = .submitting
        actionError = nil
        do {
            try await momentsRepo.softDeleteMoment(momentID: detail.id)
            await finishEditDismissing()
        } catch {
            phase = .composing
            actionError = ActionErrorState(message: CreatePostEditCopy.message(for: error))
        }
    }

    func leaveMoment() async {
        guard showsLeaveMomentAction, let momentsRepo, let detail = editDetail else { return }
        let viewerID = detail.capabilities.viewerID
        phase = .submitting
        actionError = nil
        do {
            try await momentsRepo.removeTag(momentID: detail.id, personID: viewerID)
            await finishEditDismissing()
        } catch {
            phase = .composing
            actionError = ActionErrorState(message: CreatePostEditCopy.message(for: error))
        }
    }

    // MARK: - Internals

    private func applyMediaDiffs(
        momentID: Moment.ID,
        caps: MomentCapabilities,
        moments: MomentRepository
    ) async throws {
        let currentIDs = items.compactMap(\.existingMediaID)
        let currentSet = Set(currentIDs)
        let removed = baselineMediaIDs.filter { !currentSet.contains($0) }

        for mediaID in removed {
            guard let media = editDetail?.media.first(where: { $0.id == mediaID }),
                  caps.canDeleteMedia(media) else {
                throw MomentRepositoryError.notAllowed
            }
            try await moments.softDeleteMedia(mediaID: mediaID)
        }

        // After deletes, reorder only when the remaining active set is non-empty
        // and the order (or membership) still differs from the post-delete baseline.
        let remainingBaseline = baselineMediaIDs.filter { currentSet.contains($0) }
        guard !currentIDs.isEmpty else { return }
        guard caps.canReorderMedia else {
            // Deletions without reorder are fine; a pure reorder without permission is not.
            if currentIDs != remainingBaseline,
               currentIDs.count == remainingBaseline.count {
                throw MomentRepositoryError.notAllowed
            }
            return
        }
        if currentIDs != remainingBaseline {
            try await moments.reorderMedia(momentID: momentID, orderedMediaIDs: currentIDs)
        }
    }

    private func applyMetadataAndTagDiffs(
        momentID: Moment.ID,
        caps: MomentCapabilities,
        moments: MomentRepository
    ) async throws {
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if caps.canEditMetadata,
           title != baselineTitle || location != baselineLocation {
            try await moments.updateMetadata(
                momentID: momentID, title: title, locationText: location
            )
        }

        guard caps.canEditTags else { return }
        let viewerID = caps.viewerID
        let desired = Set(memberPersonRows.map(\.id))
        let baseline = Set(baselineTagIDs)
        let toAdd = desired.subtracting(baseline).filter { $0 != viewerID }
        let toRemove = baseline.subtracting(desired).filter { $0 != viewerID }

        if !toAdd.isEmpty {
            try await moments.addTags(momentID: momentID, personIDs: Array(toAdd))
        }
        for personID in toRemove {
            try await moments.removeTag(momentID: momentID, personID: personID)
        }
    }

    private func finishEditSaved(momentID: Moment.ID) async {
        // Refresh detail + hub so Feed revision listeners pick up the change.
        await loadEditDetail(momentID: momentID)
        stampStoreRevision()
        await load()
        phase = .success
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
    }

    /// Delete / leave / last-media auto-delete — leave the flow after refresh.
    private func finishEditDismissing() async {
        editDetail = nil
        stampStoreRevision()
        await load()
        phase = .success
        shouldDismissAfterEdit = true
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
    }

    /// Prefill cell for one server media row (bundle path or remote URL).
    static func draft(from media: MomentMedia) -> AddYoursDraftItem {
        let path = media.kind == .video
            ? (media.posterURL ?? media.posterPath ?? media.publicURL)
            : media.publicURL
        let image = AvatarImageLoader.localImage(for: path)
        return AddYoursDraftItem(
            kind: media.kind == .video ? .video : .photo,
            previewImage: image,
            existingMediaID: media.id
        )
    }

    /// Prefilled Storage media from a feed/hub card. `FeedMediaItem.id` is the
    /// `MomentMedia.ID` on repository-backed cards.
    static func draft(from media: FeedMediaItem) -> AddYoursDraftItem? {
        let existingID: MomentMedia.ID? = media.id.isEmpty ? nil : media.id
        switch media.source {
        case .assetPath(let path):
            return AddYoursDraftItem(
                kind: media.kind,
                previewImage: AvatarImageLoader.localImage(for: path),
                existingMediaID: existingID
            )
        case .solidColor(let swatch):
            return AddYoursDraftItem(
                kind: media.kind,
                previewImage: FeedMediaImageFactory.image(for: swatch),
                existingMediaID: existingID
            )
        case .loading, .missing:
            return nil
        }
    }

    func seedMedia(from mediaItems: [FeedMediaItem]) {
        let drafts = mediaItems.compactMap(Self.draft(from:)).prefix(maxSelection)
        items = Array(drafts)
        focusedIndex = AddYoursSelection.clampedIndex(0, itemCount: items.count)
    }

    func clearEditBaseline() {
        editDetail = nil
        editLoadState = .idle
        editLoadTask = nil
        shouldDismissAfterEdit = false
        baselineTitle = ""
        baselineLocation = ""
        baselineTagIDs = []
        baselineMediaIDs = []
    }
}


