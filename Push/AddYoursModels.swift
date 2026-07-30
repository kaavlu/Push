//
//  AddYoursModels.swift
//  Push
//
//  Local-only models + ViewModel for the Add Yours contribution UI pass.
//  No uploads, repos, or feed mutation.
//

import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Launch context

/// Payload when opening Add Yours from a Push media card.
struct AddYoursContext: Identifiable, Equatable {
    /// Stable identity for `fullScreenCover(item:)` — typically the carousel / push id.
    let id: String
    let locationTitle: String
    let dateTimeLabel: String

    init(id: String, locationTitle: String, dateTimeLabel: String) {
        self.id = id
        self.locationTitle = locationTitle
        self.dateTimeLabel = dateTimeLabel
    }

    init(carousel: FeedMediaCarouselData) {
        self.id = carousel.id
        self.locationTitle = carousel.locationTitle
        self.dateTimeLabel = carousel.dateTimeLabel
    }

    /// Instructional subtitle — fixed product copy (no location).
    var subtitle: String {
        AddYoursCopy.subtitle
    }
}

// MARK: - Draft media

struct AddYoursDraftItem: Identifiable {
    let id: UUID
    let kind: FeedMediaKind
    /// Decoded still for photos; optional poster for videos (nil → branded placeholder).
    let previewImage: UIImage?
    /// Processed bytes for publish. Nil for prefilled media that already lives in
    /// Storage (existing-Moment edit) and for preview/test drafts — those items
    /// can be shown but never re-uploaded.
    let upload: MomentMediaUpload?

    init(
        id: UUID = UUID(),
        kind: FeedMediaKind,
        previewImage: UIImage?,
        upload: MomentMediaUpload? = nil
    ) {
        self.id = id
        self.kind = kind
        self.previewImage = previewImage
        self.upload = upload
    }
}

// MARK: - Phase

enum AddYoursPhase: Equatable {
    case composing
    case submitting
    case success
}

// MARK: - Timing (injectable for tests)

struct AddYoursTiming {
    var submitDelayNanoseconds: UInt64
    var successHoldNanoseconds: UInt64

    static let production = AddYoursTiming(
        submitDelayNanoseconds: 380_000_000,
        successHoldNanoseconds: 950_000_000
    )

    static let immediate = AddYoursTiming(
        submitDelayNanoseconds: 0,
        successHoldNanoseconds: 0
    )
}

// MARK: - Copy

enum AddYoursCopy {
    static let title = "Add yours"
    static let subtitle = "Share photos and videos"
    static let emptyPrompt = "Choose from library"
    static let emptyHint = "Photos and videos · up to \(AddYoursLayout.maxSelectionCount)"
    static let selectedSection = "Selected"
    static let addMoreAccessibility = "Add more media"
    static let removeAccessibility = "Remove media"
    static let primaryAction = "Add to push"
    static let submittingAction = "Adding…"
    static let successTitle = "Added to push"
    static let successMessage = "Your media is ready to share with the group."
    static let videoBadgeAccessibility = "Video"

    static func selectedCountLabel(count: Int, max: Int) -> String {
        "\(count) of \(max)"
    }
}

// MARK: - ViewModel

@MainActor
final class AddYoursViewModel: ObservableObject {
    let context: AddYoursContext

    @Published private(set) var items: [AddYoursDraftItem] = []
    @Published var focusedIndex: Int = 0
    @Published var pickerItems: [PhotosPickerItem] = [] {
        didSet {
            guard !pickerItems.isEmpty else { return }
            Task { await consumePickerItems() }
        }
    }
    @Published private(set) var phase: AddYoursPhase = .composing
    @Published private(set) var isLoadingPicker = false

    private let timing: AddYoursTiming
    private let maxSelection: Int

    var canSubmit: Bool {
        !items.isEmpty && phase == .composing && !isLoadingPicker
    }

    var canAddMore: Bool {
        items.count < maxSelection && phase == .composing
    }

    var remainingSlots: Int {
        max(0, maxSelection - items.count)
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

    init(
        context: AddYoursContext,
        timing: AddYoursTiming = .production,
        maxSelection: Int = AddYoursLayout.maxSelectionCount
    ) {
        self.context = context
        self.timing = timing
        self.maxSelection = max(1, maxSelection)
    }

    /// DEBUG / preview helper — seed without PhotosPicker.
    func seed(with draftItems: [AddYoursDraftItem]) {
        guard phase == .composing else { return }
        let capped = Array(draftItems.prefix(maxSelection))
        items = capped
        focusedIndex = AddYoursSelection.clampedIndex(0, itemCount: capped.count)
    }

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

    func submit() async {
        guard canSubmit else { return }
        phase = .submitting
        if timing.submitDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.submitDelayNanoseconds)
        }
        // Local-only: no upload / feed mutation.
        phase = .success
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
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
            if let draft = await Self.loadDraft(from: item) {
                loaded.append(draft)
            }
        }
        applyLoadedDrafts(loaded)
    }

    /// Appends drafts and focuses the first uploaded item (index 0).
    func applyLoadedDrafts(_ drafts: [AddYoursDraftItem]) {
        guard phase == .composing, !drafts.isEmpty else { return }
        var next = items
        for draft in drafts {
            guard next.count < maxSelection else { break }
            next.append(draft)
        }
        items = next
        // Always show the first media the user contributed, not the newest.
        focusedIndex = 0
    }

    private static func loadDraft(from item: PhotosPickerItem) async -> AddYoursDraftItem? {
        let isVideo = item.supportedContentTypes.contains { type in
            type.conforms(to: .movie)
                || type.conforms(to: .video)
                || type.identifier.contains("video")
                || type.identifier.contains("movie")
        }

        if isVideo {
            // Avoid loading full movie bytes into memory for this UI pass.
            // Poster extraction ships with real uploads later.
            return AddYoursDraftItem(kind: .video, previewImage: nil)
        }

        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else {
            return nil
        }
        return AddYoursDraftItem(kind: .photo, previewImage: image)
    }
}

// MARK: - Selection helper

enum AddYoursSelection {
    static func clampedIndex(_ index: Int, itemCount: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(max(0, index), itemCount - 1)
    }
}

// MARK: - Fixtures (DEBUG / previews)

enum AddYoursFixtures {
    static let sampleContext = AddYoursContext(
        id: "fixture-addyours-dolores",
        locationTitle: "Dolores Park",
        dateTimeLabel: "Sat · 4:30 PM"
    )

    static func sampleDraftItems() -> [AddYoursDraftItem] {
        let paths = [
            "assets/friends/ohm.png",
            "assets/friends/viplove.png",
            "assets/friends/ram.png",
        ]
        var drafts: [AddYoursDraftItem] = paths.compactMap { path in
            guard let image = loadBundleImage(path: path) else { return nil }
            return AddYoursDraftItem(kind: .photo, previewImage: image)
        }
        drafts.append(AddYoursDraftItem(kind: .video, previewImage: nil))
        return drafts
    }

    private static func loadBundleImage(path: String) -> UIImage? {
        AvatarImageLoader.localImage(for: path)
    }
}
