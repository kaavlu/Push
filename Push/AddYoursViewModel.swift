//
//  AddYoursViewModel.swift
//  Push
//
//  Add Yours state: loads the current `MomentDetail` for the launch context,
//  shapes the affordance from server capabilities, and holds the picked drafts.
//  The upload → append → refresh sequence lives in `AddYoursViewModel+Append`.
//

import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class AddYoursViewModel: ObservableObject {
    let context: AddYoursContext

    @Published internal(set) var items: [AddYoursDraftItem] = []
    @Published var focusedIndex: Int = 0
    @Published var pickerItems: [PhotosPickerItem] = [] {
        didSet {
            guard !pickerItems.isEmpty else { return }
            Task { await consumePickerItems() }
        }
    }
    @Published internal(set) var phase: AddYoursPhase = .composing
    @Published private(set) var isLoadingPicker = false
    /// The Moment this screen appends to. Reloaded after every append so the
    /// remaining capacity and capability flags stay the server's, not a guess.
    @Published internal(set) var detail: MomentDetail?
    @Published internal(set) var loadState: LoadState<Void> = .idle
    /// Recoverable append failure. The unsent drafts stay put so Retry resubmits
    /// exactly the items that were never committed.
    @Published internal(set) var actionError: ActionErrorState?

    let timing: AddYoursTiming
    let maxSelection: Int
    /// Nil only on the preview seam, which never touches repositories.
    let container: AppDataContainer?
    /// Test/preview seams so a fake or failing repository / bucket can be injected.
    private let momentsOverride: MomentRepository?
    private let mediaStorageOverride: MomentMediaStoring?
    /// Handle on the bootstrap detail load so tests can await it instead of racing.
    private(set) var initialLoad: Task<Void, Never>?

    var momentsRepo: MomentRepository? { momentsOverride ?? container?.moments }
    var mediaStorage: MomentMediaStoring? { mediaStorageOverride ?? container?.momentMedia }

    // MARK: - Derived state

    /// Server-provided (contract §10). False also while the detail is loading —
    /// the affordance is never enabled on an assumption.
    var canAddMedia: Bool { detail?.capabilities.canAddMedia ?? false }

    /// Slots left on the Moment itself (contract §4.1), from the viewer-visible
    /// album the repository just returned.
    var remainingCapacity: Int {
        guard let detail else { return 0 }
        return max(0, MomentLimits.maxActiveMedia - detail.media.count)
    }

    /// Slots left in this submission: the Moment's capacity, the per-screen cap,
    /// and what has already been picked.
    var remainingSlots: Int {
        max(0, min(maxSelection, remainingCapacity) - items.count)
    }

    var canSubmit: Bool {
        !items.isEmpty && phase == .composing && !isLoadingPicker && canAddMedia
    }

    var canAddMore: Bool {
        remainingSlots > 0 && phase == .composing && canAddMedia
    }

    /// Loaded, allowed, but the album is already full — a dead-end worth naming
    /// instead of showing a picker that can accept nothing.
    var isFull: Bool {
        detail != nil && canAddMedia && remainingCapacity == 0 && items.isEmpty
    }

    /// Loaded and the server says no. Feed hides the button, so this only shows
    /// on a stale card or a permission that changed while the sheet was open.
    var isDenied: Bool {
        detail != nil && !canAddMedia
    }

    var contentPhase: SurfaceContentPhase {
        if detail != nil { return .content }
        switch loadState {
        case .idle, .loading: return .loading
        case .failed: return .failed
        case .loaded: return .content
        }
    }

    var focusedItem: AddYoursDraftItem? {
        guard items.indices.contains(focusedIndex) else { return nil }
        return items[focusedIndex]
    }

    var primaryButtonTitle: String {
        phase == .submitting ? AddYoursCopy.submittingAction : AddYoursCopy.primaryAction
    }

    var isPrimaryLoading: Bool {
        phase == .submitting
    }

    // `container` defaults via `?? .shared` (not `= .shared`) — `.shared` is a
    // MainActor mutable static and cannot be a default argument.
    init(
        context: AddYoursContext,
        container: AppDataContainer? = nil,
        moments: MomentRepository? = nil,
        mediaStorage: MomentMediaStoring? = nil,
        timing: AddYoursTiming = .production,
        maxSelection: Int = AddYoursLayout.maxSelectionCount
    ) {
        self.context = context
        self.container = container ?? .shared
        self.momentsOverride = moments
        self.mediaStorageOverride = mediaStorage
        self.timing = timing
        self.maxSelection = max(1, maxSelection)
        initialLoad = Task { [weak self] in await self?.load() }
    }

    /// Preview / design-lab seam. Never used by the app: it has no repositories,
    /// so a fixture album can't be mistaken for a loaded Moment or be published.
    init(
        previewDetail: MomentDetail,
        items: [AddYoursDraftItem] = [],
        timing: AddYoursTiming = .production,
        maxSelection: Int = AddYoursLayout.maxSelectionCount
    ) {
        self.context = AddYoursContext(momentID: previewDetail.id)
        self.container = nil
        self.momentsOverride = nil
        self.mediaStorageOverride = nil
        self.timing = timing
        self.maxSelection = max(1, maxSelection)
        self.detail = previewDetail
        self.items = Array(items.prefix(max(1, maxSelection)))
        self.loadState = .loaded(())
    }

    // MARK: - Loading

    /// Current album + capabilities for the launch context. Keeps whatever is on
    /// screen while it is in flight so a post-append refresh never blanks out.
    func load() async {
        guard let momentsRepo else {
            loadState = .failed(MomentRepositoryError.notFound)
            return
        }
        if detail == nil { loadState = .loading }
        do {
            detail = try await momentsRepo.moment(id: context.momentID)
            loadState = .loaded(())
        } catch {
            // A failed refresh must not discard a detail (and drafts) already shown.
            if detail == nil { loadState = .failed(error) }
        }
    }

    // MARK: - Selection

    func selectItem(at index: Int) {
        guard phase == .composing else { return }
        focusedIndex = AddYoursSelection.clampedIndex(index, itemCount: items.count)
    }

    func removeFocusedItem() {
        removeItem(at: focusedIndex)
    }

    func removeItem(at index: Int) {
        guard phase == .composing, items.indices.contains(index) else { return }
        items.remove(at: index)
        focusedIndex = AddYoursSelection.clampedIndex(
            min(index, items.count - 1),
            itemCount: items.count
        )
    }

    /// Appends drafts and focuses the first uploaded item (index 0).
    func applyLoadedDrafts(_ drafts: [AddYoursDraftItem]) {
        guard phase == .composing, !drafts.isEmpty else { return }
        var next = items
        for draft in drafts {
            guard next.count - items.count < remainingSlots else { break }
            next.append(draft)
        }
        items = next
        // Always show the first media the user contributed, not the newest.
        focusedIndex = 0
    }

    // MARK: - Picker

    private func consumePickerItems() async {
        let batch = pickerItems
        pickerItems = []
        guard phase == .composing, !batch.isEmpty else { return }

        isLoadingPicker = true
        defer { isLoadingPicker = false }

        var loaded: [AddYoursDraftItem] = []
        loaded.reserveCapacity(min(batch.count, remainingSlots))
        for item in batch {
            guard loaded.count < remainingSlots else { break }
            // Same loader as Create Post: drafts carry the bytes the append uploads.
            if let draft = await CreatePostMediaLoader.draft(from: item) {
                loaded.append(draft)
            }
        }
        applyLoadedDrafts(loaded)
    }
}
