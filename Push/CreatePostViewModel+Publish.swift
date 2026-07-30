//
//  CreatePostViewModel+Publish.swift
//  Push
//
//  Publish path for scratch and past-Push drafts (architecture S7 §6.5–6.6):
//  local validation → `MomentMediaPublisher.publishPending` (upload, commit,
//  orphan rollback) → `MomentRepository.createMoment` → hub/Feed refresh.
//  Failures keep the draft so Retry can resubmit; every rolled-back attempt
//  re-uploads under fresh object keys, so a retry can neither duplicate a
//  committed Moment nor leave Storage objects behind.
//

import Foundation

@MainActor
extension CreatePostViewModel {

    func dismissActionError() {
        actionError = nil
    }

    /// Banner Retry — resubmits the failed publish or existing-Moment save.
    func retryPublish() async {
        await submit()
    }

    func submit() async {
        guard canSubmit else { return }
        actionError = nil

        // Existing-Moment edit (S9) — never createMoment; never simulate on repo paths.
        if isEditingExistingMoment {
            if isRepositoryBacked {
                await saveExistingMomentEdits()
            } else {
                await finishLocally()
            }
            return
        }

        guard isRepositoryBacked else {
            await finishLocally()
            return
        }
        guard let container, let momentsRepo, let mediaStorage else {
            actionError = ActionErrorState(message: CreatePostPublishCopy.generic)
            return
        }

        phase = .submitting
        do {
            let uploads = try publishableUploads()
            let viewerID = container.currentUserID
            _ = try await MomentMediaPublisher.publishPending(
                uploads: uploads,
                userID: viewerID,
                storage: mediaStorage
            ) { results in
                try await momentsRepo.createMoment(
                    draft(
                        media: results.map(MomentMediaDraft.init(upload:)),
                        viewerID: viewerID
                    )
                )
            }
            await finishPublished()
        } catch {
            // Draft (media, title, tags) is untouched — Retry resubmits it.
            phase = .composing
            actionError = ActionErrorState(message: CreatePostPublishCopy.message(for: error))
        }
    }

    // MARK: - Draft assembly

    /// Bytes for every item in album order. Prefilled Storage media has no bytes
    /// to re-upload, so a draft mixing it with new picks is rejected locally
    /// rather than published half-empty.
    func publishableUploads() throws -> [MomentMediaUpload] {
        guard !items.isEmpty else { throw MomentRepositoryError.mediaRequired }
        guard items.count <= MomentLimits.maxActiveMedia else {
            throw MomentRepositoryError.mediaLimitExceeded
        }
        let uploads = items.compactMap(\.upload)
        guard uploads.count == items.count else {
            throw CreatePostPublishError.mediaNotUploadable
        }
        // Pre-flight the same checks Storage applies, before any network call.
        for upload in uploads {
            try MomentMediaValidator.validate(upload)
        }
        return uploads
    }

    /// The publish payload. The creator tag is implicit server-side, so the
    /// viewer is never sent as a tag id.
    func draft(media: [MomentMediaDraft], viewerID: Person.ID) -> MomentDraft {
        MomentDraft(
            title: titleText.trimmingCharacters(in: .whitespacesAndNewlines),
            locationText: locationText.trimmingCharacters(in: .whitespacesAndNewlines),
            pushID: sourcePushID,
            taggedPersonIDs: memberPersonRows.map(\.id).filter { $0 != viewerID },
            media: media
        )
    }

    /// Set only for the past-Push path — one Moment per Push, forever.
    var sourcePushID: PushPlan.ID? {
        if case .pastPush(let id) = source { return id }
        return nil
    }

    // MARK: - Completion

    private func finishPublished() async {
        phase = .success
        stampStoreRevision()
        // Hub and Feed both read from the repository; reload so the new Moment
        // is present before the flow dismisses.
        await load()
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
    }

    /// Preview seam and the S8-owned existing-Moment edit: simulated timing only.
    private func finishLocally() async {
        phase = .submitting
        if timing.submitDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.submitDelayNanoseconds)
        }
        phase = .success
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
    }
}

/// Client-only publish failures (the repository errors cover the server side).
enum CreatePostPublishError: Error, Equatable {
    /// A draft item has no bytes to upload (prefilled Storage media).
    case mediaNotUploadable
}

enum CreatePostPublishCopy {
    static let generic = "Couldn't share this moment. Try again."
    static let mediaRequired = "Add at least one photo or video."
    static let mediaLimit = "You can share up to \(MomentLimits.maxActiveMedia) items."
    static let invalidTag = "Someone you tagged can't be added. Edit the list and try again."
    static let pushTaken = "That Push already has a moment."
    static let invalidPush = "You can't make a moment from that Push."
    static let mediaRejected = "Couldn't upload that media. Try again."
    static let mediaTooLarge = "One of those files is too large."
    static let mediaUnsupported = "That file type isn't supported."
    static let notAllowed = "You can't post this moment."

    static func message(for error: Error) -> String {
        if let error = error as? MomentRepositoryError { return message(for: error) }
        if let error = error as? MomentMediaStorageError { return message(for: error) }
        if case CreatePostPublishError.mediaNotUploadable = error { return mediaRejected }
        return generic
    }

    private static func message(for error: MomentRepositoryError) -> String {
        switch error {
        case .mediaRequired: return mediaRequired
        case .mediaLimitExceeded: return mediaLimit
        case .invalidTag: return invalidTag
        case .momentExistsForPush: return pushTaken
        case .invalidPush: return invalidPush
        case .invalidMediaPath: return mediaRejected
        case .notAllowed, .notAuthenticated: return notAllowed
        case .notFound, .conflict, .cannotRemoveCreator: return generic
        }
    }

    private static func message(for error: MomentMediaStorageError) -> String {
        switch error {
        case .fileTooLarge: return mediaTooLarge
        case .unsupportedContentType: return mediaUnsupported
        case .emptyData: return mediaRejected
        }
    }
}
