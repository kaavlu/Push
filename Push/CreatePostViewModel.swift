//
//  CreatePostViewModel.swift
//  Push
//
//  Local-only ViewModel for Feed create-post hub → (scratch friends) → compose.
//

import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CreatePostViewModel: ObservableObject {
    @Published private(set) var screen: CreatePostScreen = .hub
    @Published private(set) var source: CreatePostSource = .scratch
    @Published var selectedSegment: CreatePostHubSegment = .existingMoments
    @Published private(set) var existingMoments: [CreatePostHistoryItem]
    @Published private(set) var pastPushes: [CreatePostHistoryItem]
    @Published private(set) var selectedHistoryID: String?

    /// Friend picker catalog (fixture + any prefilled members).
    @Published private(set) var availableFriends: [PushRecipientItem]
    @Published var friendSearchText: String = ""
    @Published private(set) var selectedFriendIDs: Set<String> = []
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
    @Published private(set) var phase: CreatePostPhase = .composing
    @Published private(set) var isLoadingPicker = false
    @Published private(set) var displayParticipants: [FeedMediaParticipant] = []
    /// Compose “With” section — selected friends (scratch) or original membership.
    @Published private(set) var memberPersonRows: [FriendRowModel] = []

    private let timing: CreatePostTiming
    private let maxSelection: Int
    private let baseAvailableFriends: [PushRecipientItem]
    /// Selection snapshot when opening Edit from compose — restored on cancel.
    private var friendSelectionSnapshot: Set<String> = []

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

    init(
        existingMoments: [CreatePostHistoryItem] = CreatePostFixtures.existingMoments,
        pastPushes: [CreatePostHistoryItem] = CreatePostFixtures.pastPushes,
        availableFriends: [PushRecipientItem] = CreatePostFixtures.selectableFriends,
        timing: CreatePostTiming = .production,
        maxSelection: Int = CreatePostLayout.maxSelectionCount
    ) {
        self.existingMoments = existingMoments
        self.pastPushes = pastPushes
        self.baseAvailableFriends = availableFriends
        self.availableFriends = availableFriends
        self.timing = timing
        self.maxSelection = max(1, maxSelection)
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

    /// Feed card overflow — open compose prefilled for this moment (viewer is a participant).
    func openFeedMomentForEdit(_ carousel: FeedMediaCarouselData) {
        guard phase == .composing || phase == .success else { return }
        let momentID = CreatePostHistoryItem.feedMomentID(forCarouselID: carousel.id)
        if let item = existingMoments.first(where: { $0.id == momentID }) {
            openCompose(from: item, source: .existingMoment(id: item.id))
            return
        }
        let item = CreatePostHistoryItem.fromFeedCarousel(carousel)
        openCompose(from: item, source: .existingMoment(id: item.id))
    }

    /// Prefills compose for a feed moment (used when launching edit from the Feed card).
    static func forEditingFeedMoment(
        _ carousel: FeedMediaCarouselData,
        timing: CreatePostTiming = .production
    ) -> CreatePostViewModel {
        let viewModel = CreatePostViewModel(timing: timing)
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

    // MARK: - Friend selection

    func isFriendSelected(_ id: String) -> Bool {
        selectedFriendIDs.contains(id)
    }

    func toggleFriend(_ id: String) {
        guard phase == .composing, screen == .selectFriends else { return }
        guard availableFriends.contains(where: { $0.id == id }) else { return }
        if selectedFriendIDs.contains(id) {
            selectedFriendIDs.remove(id)
        } else {
            selectedFriendIDs.insert(id)
        }
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

    func submit() async {
        guard canSubmit else { return }
        phase = .submitting
        if timing.submitDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.submitDelayNanoseconds)
        }
        phase = .success
        if timing.successHoldNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: timing.successHoldNanoseconds)
        }
    }

    // MARK: - Private

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

    private func applySelectedFriendsToMembers() {
        let byID = Dictionary(uniqueKeysWithValues: availableFriends.map { ($0.id, $0) })
        // Keep prior With order for still-selected people; append newly tagged friends.
        let retainedIDs = memberPersonRows.map(\.id).filter { selectedFriendIDs.contains($0) }
        let retainedSet = Set(retainedIDs)
        let newcomers = availableFriends.filter {
            selectedFriendIDs.contains($0.id) && !retainedSet.contains($0.id)
        }
        let ordered = retainedIDs.compactMap { byID[$0] } + newcomers

        displayParticipants = ordered.map { friend in
            FeedMediaParticipant(
                id: friend.id,
                displayName: friend.name,
                imageAssetPath: friend.imageAssetName
            )
        }
        memberPersonRows = ordered.map(Self.personRow(from:))
    }

    private func seedSelectedFriendsFromMembers() {
        mergeParticipantsIntoAvailableFriends(displayParticipants)
        // Prefer current member order; fall back to selected set already on the draft.
        if !memberPersonRows.isEmpty {
            selectedFriendIDs = Set(memberPersonRows.map(\.id))
        }
    }

    private func mergeParticipantsIntoAvailableFriends(_ people: [FeedMediaParticipant]) {
        var byID = Dictionary(uniqueKeysWithValues: availableFriends.map { ($0.id, $0) })
        for person in people where byID[person.id] == nil {
            byID[person.id] = PushRecipientItem(
                id: person.id,
                name: person.displayName,
                memberCount: nil,
                imageAssetName: person.imageAssetPath,
                initials: person.initials,
                isGroup: false
            )
        }
        // Catalog first (stable order), then any extras not already listed.
        let baseIDs = Set(baseAvailableFriends.map(\.id))
        let extras = byID.values
            .filter { !baseIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        availableFriends = baseAvailableFriends + extras
    }

    private static func personRow(from friend: PushRecipientItem) -> FriendRowModel {
        FriendRowModel(
            id: friend.id,
            friend: FriendPuckData(
                id: friend.id,
                name: friend.name,
                avatarPlaceholder: friend.initials,
                profileImageAssetName: friend.imageAssetName,
                activity: "",
                activitySymbolName: "",
                activityDisplayText: "",
                availability: .busy,
                venueStatusText: "",
                lastUpdated: ""
            ),
            groupLabel: nil
        )
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
            if let draft = await Self.loadDraft(from: item) {
                loaded.append(draft)
            }
        }
        applyLoadedDrafts(loaded)
    }

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

    private static func loadDraft(from item: PhotosPickerItem) async -> AddYoursDraftItem? {
        let isVideo = item.supportedContentTypes.contains { type in
            type.conforms(to: .movie)
                || type.conforms(to: .video)
                || type.identifier.contains("video")
                || type.identifier.contains("movie")
        }
        if isVideo {
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
