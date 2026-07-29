//
//  CreatePostViewModel.swift
//  Push
//
//  Feed create-post hub → (scratch friends) → compose. Hub rows and the friend
//  catalog come from repositories (see `CreatePostViewModel+Hub`), and publish
//  goes through Storage + `MomentRepository` (see `CreatePostViewModel+Publish`).
//  Fixture lists survive only behind the preview initializer.
//

import Combine
import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CreatePostViewModel: ObservableObject {
    // `internal(set)` (not `private(set)`) on the state the `+Hub`, `+Friends`,
    // and `+Publish` extensions own — a `private` setter is file-scoped, and this
    // view model is split by responsibility to stay inside the file-size rule.
    @Published private(set) var screen: CreatePostScreen = .hub
    @Published private(set) var source: CreatePostSource = .scratch
    @Published var selectedSegment: CreatePostHubSegment = .existingMoments
    @Published internal(set) var existingMoments: [CreatePostHistoryItem]
    @Published internal(set) var pastPushes: [CreatePostHistoryItem]
    @Published private(set) var selectedHistoryID: String?
    /// Hub chooser load (Existing Moments + Past Pushes + friend catalog).
    @Published internal(set) var hubLoadState: LoadState<Void> = .idle
    /// Recoverable publish failure. The draft stays intact so Retry can resubmit.
    @Published internal(set) var actionError: ActionErrorState?

    /// Friend picker catalog — the viewer's friends, plus anyone already tagged.
    @Published internal(set) var availableFriends: [PushRecipientItem]
    @Published var friendSearchText: String = ""
    @Published internal(set) var selectedFriendIDs: Set<String> = []
    /// Drives friend-picker back target and navigation stack shape.
    @Published private(set) var friendPickerEntry: CreatePostFriendPickerEntry = .initialScratch

    @Published var titleText: String = "" {
        didSet {
            if titleText.count > CreatePostLayout.titleMaxLength {
                titleText = String(titleText.prefix(CreatePostLayout.titleMaxLength))
            }
        }
    }
    @Published var locationText: String = "" {
        didSet {
            if locationText.count > CreatePostLayout.locationMaxLength {
                locationText = String(locationText.prefix(CreatePostLayout.locationMaxLength))
            }
        }
    }

    @Published private(set) var items: [AddYoursDraftItem] = []
    @Published var focusedIndex: Int = 0
    @Published var pickerItems: [PhotosPickerItem] = [] {
        didSet {
            guard !pickerItems.isEmpty else { return }
            Task { await consumePickerItems() }
        }
    }
    @Published internal(set) var phase: CreatePostPhase = .composing
    @Published private(set) var isLoadingPicker = false
    @Published internal(set) var displayParticipants: [FeedMediaParticipant] = []
    /// Compose “With” section — selected friends (scratch) or original membership.
    @Published internal(set) var memberPersonRows: [FriendRowModel] = []

    let timing: CreatePostTiming
    let maxSelection: Int
    /// Nil only on the preview seam, which never touches repositories.
    let container: AppDataContainer?
    /// Test/preview seams so a fake or failing repository / bucket can be injected.
    let momentsOverride: MomentRepository?
    let mediaStorageOverride: MomentMediaStoring?
    /// People cache for tag ids → faces, shared by hub rows and the friend catalog.
    var peopleByID: [Person.ID: Person] = [:]
    /// Push slots the viewer can already see consumed by a Moment (chooser hint).
    var momentPushIDs: Set<PushPlan.ID> = []
    var baseAvailableFriends: [PushRecipientItem]
    /// Handle on the bootstrap hub load so tests can await it instead of racing.
    private(set) var initialLoad: Task<Void, Never>?
    /// Selection snapshot when opening Edit from compose — restored on cancel.
    private var friendSelectionSnapshot: Set<String> = []
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0

    // `container` defaults via `?? .shared` (not `= .shared`) — `.shared` is a
    // MainActor mutable static and cannot be a default argument.
    init(
        container: AppDataContainer? = nil,
        moments: MomentRepository? = nil,
        mediaStorage: MomentMediaStoring? = nil,
        timing: CreatePostTiming = .production,
        maxSelection: Int = CreatePostLayout.maxSelectionCount
    ) {
        let container = container ?? .shared
        self.container = container
        self.momentsOverride = moments
        self.mediaStorageOverride = mediaStorage
        self.timing = timing
        self.maxSelection = max(1, maxSelection)
        self.existingMoments = []
        self.pastPushes = []
        self.baseAvailableFriends = []
        self.availableFriends = []
        initialLoad = Task { await load() }
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    /// Preview / design-lab seam. Never used by the app: it has no repositories,
    /// so fixture rows can't leak into a session and publish stays simulated.
    init(
        existingMoments: [CreatePostHistoryItem],
        pastPushes: [CreatePostHistoryItem] = [],
        availableFriends: [PushRecipientItem] = CreatePostFixtures.selectableFriends,
        timing: CreatePostTiming = .production,
        maxSelection: Int = CreatePostLayout.maxSelectionCount
    ) {
        self.container = nil
        self.momentsOverride = nil
        self.mediaStorageOverride = nil
        self.timing = timing
        self.maxSelection = max(1, maxSelection)
        self.existingMoments = existingMoments
        self.pastPushes = pastPushes
        self.baseAvailableFriends = availableFriends
        self.availableFriends = availableFriends
        self.hubLoadState = .loaded(())
    }

    // MARK: - Navigation

    func startFromScratch() {
        guard phase == .composing || phase == .success else { return }
        resetDraft()
        source = .scratch
        friendPickerEntry = .initialScratch
        screen = .selectFriends
        phase = .composing
    }

    /// Opens compose for either segment — existing moment edit or past-Push create.
    func selectChooserItem(id: String) {
        guard phase == .composing || phase == .success else { return }
        if let item = existingMoments.first(where: { $0.id == id }) {
            openCompose(from: item, source: .existingMoment(id: id))
            return
        }
        if let item = pastPushes.first(where: { $0.id == id }) {
            openCompose(from: item, source: .pastPush(id: id))
        }
    }

    /// Feed card overflow — open compose prefilled for this moment (viewer is a
    /// participant). The feed card id **is** the Moment id (S6).
    func openFeedMomentForEdit(_ carousel: FeedMediaCarouselData) {
        guard phase == .composing || phase == .success else { return }
        if let item = existingMoments.first(where: { $0.id == carousel.id }) {
            openCompose(from: item, source: .existingMoment(id: item.id))
            return
        }
        let item = CreatePostHistoryItem.fromFeedCarousel(carousel)
        openCompose(from: item, source: .existingMoment(id: item.id))
    }

    /// Prefills compose for a feed moment (used when launching edit from the Feed card).
    static func forEditingFeedMoment(
        _ carousel: FeedMediaCarouselData,
        container: AppDataContainer? = nil,
        timing: CreatePostTiming = .production
    ) -> CreatePostViewModel {
        let viewModel = CreatePostViewModel(container: container, timing: timing)
        viewModel.openFeedMomentForEdit(carousel)
        return viewModel
    }

    /// Back-compat for tests that target past-Push selection by id.
    func selectHistoryItem(id: String) {
        selectChooserItem(id: id)
    }

    func continueFromFriends() {
        guard canContinueFromFriends else { return }
        applySelectedFriendsToMembers()
        // Entry only matters while the picker is open; reset for the next open.
        friendPickerEntry = .initialScratch
        screen = .compose
        phase = .composing
    }

    /// Compose chrome Back on scratch — return to the initial friend step.
    func goBackToSelectFriends() {
        guard phase != .submitting else { return }
        guard usesFriendSelection, screen == .compose else { return }
        seedSelectedFriendsFromMembers()
        friendPickerEntry = .initialScratch
        friendSearchText = ""
        screen = .selectFriends
        phase = .composing
    }

    /// Compose “With · Edit” — open picker for any source; keeps media/title draft.
    func openFriendEditor() {
        guard canEditPeople else { return }
        seedSelectedFriendsFromMembers()
        friendSelectionSnapshot = selectedFriendIDs
        friendPickerEntry = .editFromCompose
        friendSearchText = ""
        screen = .selectFriends
        phase = .composing
    }

    /// Friend picker Back / swipe cancel when editing from compose.
    func cancelFriendEditor() {
        guard phase != .submitting else { return }
        guard screen == .selectFriends, isEditingPeopleFromCompose else { return }
        selectedFriendIDs = friendSelectionSnapshot
        friendSearchText = ""
        friendPickerEntry = .initialScratch
        screen = .compose
        phase = .composing
    }

    /// Friend picker Back when on the initial scratch step.
    func goBackFromFriendPicker() {
        guard phase != .submitting, screen == .selectFriends else { return }
        if isEditingPeopleFromCompose {
            cancelFriendEditor()
        } else {
            goBackToHub()
        }
    }

    func goBackToHub() {
        guard phase != .submitting else { return }
        resetDraft()
        screen = .hub
        phase = .composing
    }

    // MARK: - Media

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

    /// Reorders media; index 0 remains the feed thumbnail after the move.
    func moveMedia(from fromIndex: Int, to toIndex: Int) {
        guard phase == .composing else { return }
        guard items.indices.contains(fromIndex) else { return }
        guard fromIndex != toIndex else { return }
        let clampedTo = min(max(0, toIndex), items.count - 1)
        guard fromIndex != clampedTo else { return }

        let focusedID = items.indices.contains(focusedIndex) ? items[focusedIndex].id : nil
        var next = items
        let moved = next.remove(at: fromIndex)
        next.insert(moved, at: clampedTo)
        items = next

        if let focusedID, let newFocus = next.firstIndex(where: { $0.id == focusedID }) {
            focusedIndex = newFocus
        } else {
            focusedIndex = AddYoursSelection.clampedIndex(focusedIndex, itemCount: next.count)
        }
    }

    func applyLoadedDrafts(_ drafts: [AddYoursDraftItem]) {
        guard phase == .composing, !drafts.isEmpty else { return }
        var next = items
        for draft in drafts {
            guard next.count < maxSelection else { break }
            next.append(draft)
        }
        items = next
        focusedIndex = 0
    }

    // MARK: - Internals

    /// Stamped after every successful load / publish so the store subscription
    /// can tell its own write apart from someone else's.
    func stampStoreRevision() {
        lastSeenRevision = container?.storeRevision ?? lastSeenRevision
    }

    private func openCompose(from item: CreatePostHistoryItem, source: CreatePostSource) {
        resetDraft()
        self.source = source
        selectedHistoryID = item.id
        titleText = item.title
        locationText = item.locationTitle
        displayParticipants = item.participants
        memberPersonRows = item.memberPersonRows
        mergeParticipantsIntoAvailableFriends(item.participants)
        selectedFriendIDs = Set(item.participants.map(\.id))
        seedMedia(from: item.mediaItems)
        screen = .compose
        phase = .composing
    }

    private func resetDraft() {
        titleText = ""
        locationText = ""
        items = []
        focusedIndex = 0
        pickerItems = []
        isLoadingPicker = false
        displayParticipants = []
        memberPersonRows = []
        selectedHistoryID = nil
        source = .scratch
        friendSearchText = ""
        selectedFriendIDs = []
        friendSelectionSnapshot = []
        friendPickerEntry = .initialScratch
        availableFriends = baseAvailableFriends
        actionError = nil
    }

    private func seedMedia(from mediaItems: [FeedMediaItem]) {
        let drafts = mediaItems.compactMap(Self.draft(from:)).prefix(maxSelection)
        items = Array(drafts)
        focusedIndex = AddYoursSelection.clampedIndex(0, itemCount: items.count)
    }

    private func consumePickerItems() async {
        let batch = pickerItems
        pickerItems = []
        guard phase == .composing, screen == .compose, !batch.isEmpty else { return }

        isLoadingPicker = true
        defer { isLoadingPicker = false }

        var loaded: [AddYoursDraftItem] = []
        loaded.reserveCapacity(min(batch.count, remainingSlots))
        for item in batch {
            guard loaded.count < remainingSlots else { break }
            if let draft = await CreatePostMediaLoader.draft(from: item) {
                loaded.append(draft)
            }
        }
        applyLoadedDrafts(loaded)
    }

    /// Prefilled media that already lives in Storage: previewable, never re-uploaded.
    private static func draft(from media: FeedMediaItem) -> AddYoursDraftItem? {
        switch media.source {
        case .assetPath(let path):
            let image = AvatarImageLoader.localImage(for: path)
            return AddYoursDraftItem(kind: media.kind, previewImage: image)
        case .solidColor(let swatch):
            return AddYoursDraftItem(
                kind: media.kind,
                previewImage: FeedMediaImageFactory.image(for: swatch)
            )
        case .loading, .missing:
            return nil
        }
    }
}
