//
//  AddYoursViewModel+Append.swift
//  Push
//
//  Add Yours append path (architecture S8 §6.7): per item, upload to the
//  Moment's Storage folder → `MomentRepository.appendMedia` → refresh.
//
//  Deliberately item-by-item rather than one batched call: `append_moment_media`
//  commits per item, so a rejection (usually a concurrent cap hit) must leave the
//  items that already committed alone and roll back only its own object. The
//  committed drafts leave the composer, so Retry resubmits exactly the remainder.
//

import Foundation

@MainActor
extension AddYoursViewModel {

    func dismissActionError() {
        actionError = nil
    }

    /// Banner Retry — the unsent drafts are the only retryable work here.
    func retrySubmit() async {
        await submit()
    }

    func submit() async {
        guard canSubmit, let detail, let momentsRepo, let mediaStorage, let container else {
            return
        }
        actionError = nil
        phase = .submitting
        if timing.submitDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.submitDelayNanoseconds)
        }

        var committed = 0
        do {
            try validateDraft()
            // `items.first` each pass: committed drafts are removed as they land,
            // so a mid-batch failure leaves exactly the uncommitted remainder.
            while let item = items.first {
                try await append(
                    item,
                    momentID: detail.id,
                    viewerID: container.currentUserID,
                    storage: mediaStorage,
                    repository: momentsRepo
                )
                dropCommittedItem()
                committed += 1
            }
            await finishAppended()
        } catch {
            await finishFailed(error, committed: committed)
        }
    }

    // MARK: - One item

    /// Upload then commit. `MomentMediaPublisher.append` deletes the object again
    /// when the RPC rejects it, so a failure can never leave a Storage orphan.
    private func append(
        _ item: AddYoursDraftItem,
        momentID: Moment.ID,
        viewerID: Person.ID,
        storage: MomentMediaStoring,
        repository: MomentRepository
    ) async throws {
        guard let upload = item.upload else { throw AddYoursAppendError.mediaNotUploadable }
        try await MomentMediaPublisher.append(
            upload: upload,
            momentID: momentID,
            userID: viewerID,
            storage: storage,
            // Tagged members may write under `{moment_id}/…` (migration 0024).
            useMomentFolder: true
        ) { result in
            try await repository.appendMedia(
                momentID: momentID,
                items: [MomentMediaDraft(upload: result)]
            )
        }
    }

    // MARK: - Validation

    /// Local pre-flight against the detail the viewer is looking at. The server
    /// re-checks everything: a concurrent append can still push the Moment over
    /// the cap between this check and the RPC, which arrives as a normal
    /// recoverable `mediaLimitExceeded`.
    func validateDraft() throws {
        guard !items.isEmpty else { throw MomentRepositoryError.mediaRequired }
        guard items.count <= remainingCapacity else {
            throw MomentRepositoryError.mediaLimitExceeded
        }
        for item in items {
            guard let upload = item.upload else { throw AddYoursAppendError.mediaNotUploadable }
            try MomentMediaValidator.validate(upload)
        }
    }

    // MARK: - Completion

    private func dropCommittedItem() {
        items.removeFirst()
        focusedIndex = AddYoursSelection.clampedIndex(0, itemCount: items.count)
    }

    private func finishAppended() async {
        phase = .success
        // Feed reads from the repository: the mock store bumped its revision on
        // append and the live store was notified, so both refresh themselves.
        await load()
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
    }

    /// Recoverable: the composer comes back with the uncommitted drafts intact
    /// and a refreshed capacity, so Retry submits the remainder against current
    /// server state.
    private func finishFailed(_ error: Error, committed: Int) async {
        phase = .composing
        await load()
        actionError = ActionErrorState(
            message: AddYoursAppendCopy.message(for: error, committed: committed)
        )
    }
}

/// Client-only append failures (repository errors cover the server side).
enum AddYoursAppendError: Error, Equatable {
    /// A draft has no bytes to upload (preview/prefilled media).
    case mediaNotUploadable
}

enum AddYoursAppendCopy {
    static let generic = "Couldn't add your media. Try again."
    static let mediaRequired = "Pick at least one photo or video."
    static let mediaLimit = "This moment is full — up to \(MomentLimits.maxActiveMedia) items."
    static let notAllowed = "You can't add to this moment anymore."
    static let notFound = "This moment isn't available anymore."
    static let mediaRejected = "Couldn't upload that media. Try again."
    static let mediaTooLarge = "One of those files is too large."
    static let mediaUnsupported = "That file type isn't supported."

    /// Partial success is stated plainly: what landed is permanent, and the
    /// banner's Retry only covers what is still in the composer.
    static func partialPrefix(committed: Int) -> String {
        committed == 1
            ? "Added 1 item. "
            : "Added \(committed) items. "
    }

    static func message(for error: Error, committed: Int) -> String {
        let detail = message(for: error)
        guard committed > 0 else { return detail }
        return partialPrefix(committed: committed) + detail
    }

    static func message(for error: Error) -> String {
        if let error = error as? MomentRepositoryError { return message(for: error) }
        if let error = error as? MomentMediaStorageError { return message(for: error) }
        if case AddYoursAppendError.mediaNotUploadable = error { return mediaRejected }
        return generic
    }

    private static func message(for error: MomentRepositoryError) -> String {
        switch error {
        case .mediaRequired: return mediaRequired
        case .mediaLimitExceeded: return mediaLimit
        case .notFound: return notFound
        case .invalidMediaPath: return mediaRejected
        case .notAllowed, .notAuthenticated: return notAllowed
        case .invalidTag, .invalidPush, .momentExistsForPush,
             .cannotRemoveCreator, .conflict:
            return generic
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
