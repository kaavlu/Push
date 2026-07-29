//
//  FeedViewModel.swift
//  Push
//
//  Feed shell state. Feed › Pushes loads Moments from `MomentRepository`
//  (Issue #125 / architecture S6 §6.1): keyset pagination, repository-backed
//  group chips, refresh, and retry. Fixtures survive only as preview seeds —
//  no app path falls back to them.
//

import Combine
import Foundation

@MainActor
final class FeedViewModel: ObservableObject {
    @Published var selectedTab: FeedTab = .pushes
    /// Persists across Pushes/Now switches for the session.
    @Published private(set) var selectedFilterID: String = MomentFeedFilter.allID
    /// "All" plus the viewer's groups (contract §7.8).
    @Published private(set) var filterItems: [PushIvoryFilterItem] = [MomentFeedFilter.allItem]

    /// Repository-backed Moment cards for the Pushes tab, page order preserved.
    @Published private(set) var mediaCarousels: [FeedMediaCarouselData] = []
    @Published private(set) var loadState: LoadState<[FeedMediaCarouselData]> = .idle
    @Published private(set) var isLoadingMore = false
    /// Recoverable pagination failure — content stays on screen with a Retry banner.
    @Published private(set) var actionError: ActionErrorState?

    private let container: AppDataContainer?
    /// Test/preview seam so a failing or fake repository can be injected.
    private let momentsOverride: MomentRepository?
    private var nextCursor: MomentFeedCursor?
    private var loadedMomentIDs: Set<Moment.ID> = []
    private var peopleByID: [Person.ID: Person] = [:]
    private var storeChangeSub: AnyCancellable?
    private var lastSeenRevision = 0
    /// Handle on the initializer's first load so tests can await bootstrap
    /// instead of racing it.
    private(set) var initialLoad: Task<Void, Never>?
    /// Bumped by every first-page load so a slower in-flight page (older filter)
    /// can never overwrite newer content.
    private var loadGeneration = 0

    private var momentsRepo: MomentRepository? { momentsOverride ?? container?.moments }

    /// Nil for "All" — no group predicate.
    private var groupFilterID: FriendGroup.ID? {
        selectedFilterID == MomentFeedFilter.allID ? nil : selectedFilterID
    }

    var hasMorePages: Bool { nextCursor != nil }

    /// Drives the shared surface family (DS-070). Content wins whenever cards
    /// are on screen, so refreshing and incremental failures never blank out.
    var contentPhase: SurfaceContentPhase {
        guard mediaCarousels.isEmpty else { return .content }
        switch loadState {
        case .idle, .loading: return .loading
        case .failed: return .failed
        case .loaded: return .empty
        }
    }

    // `container` defaults via `?? .shared` (not `= .shared`) — `.shared` is a
    // MainActor mutable static; the fallback must live in the initializer body.
    init(container: AppDataContainer? = nil, moments: MomentRepository? = nil) {
        let container = container ?? .shared
        self.container = container
        self.momentsOverride = moments
        initialLoad = Task { await load() }
        storeChangeSub = container.onStoreChange { [weak self] revision in
            guard let self, revision != self.lastSeenRevision else { return }
            Task { await self.load() }
        }
    }

    /// Preview / design-lab seam. Never used by the app: it bypasses the
    /// repository entirely, which is why fixtures can't leak into a session.
    init(
        carousels: [FeedMediaCarouselData],
        filterItems: [PushIvoryFilterItem] = [MomentFeedFilter.allItem]
    ) {
        container = nil
        momentsOverride = nil
        mediaCarousels = carousels
        self.filterItems = filterItems
        loadState = .loaded(carousels)
    }

    var selectedTabID: String {
        get { selectedTab.rawValue }
        set { selectedTab = FeedTab(rawValue: newValue) ?? .pushes }
    }

    func selectTab(_ tab: FeedTab) {
        selectedTab = tab
    }

    // MARK: - Loading

    /// First page for the current filter, keeping any existing cards visible
    /// while it is in flight (soft load).
    func load() async {
        await loadFirstPage(clearingContent: false)
    }

    /// Pull-to-refresh: re-warm the live session, then replace from page one.
    func refresh() async {
        try? await container?.refreshSession()
        await loadFirstPage(clearingContent: false)
    }

    /// Next keyset page. No-op at the end of the feed or while one is in flight.
    func loadMore() async {
        guard let momentsRepo, let cursor = nextCursor, !isLoadingMore else { return }
        let generation = loadGeneration
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await momentsRepo.feedPage(
                cursor: cursor,
                limit: MomentLimits.defaultFeedPageSize,
                groupID: groupFilterID
            )
            guard generation == loadGeneration else { return }
            append(page)
            actionError = nil
        } catch {
            guard generation == loadGeneration else { return }
            actionError = ActionErrorState(message: MomentFeedCopy.loadMoreFailed)
        }
    }

    /// Called as the last card appears; ignores earlier cards.
    func loadMoreIfNeeded(after cardID: String) async {
        guard mediaCarousels.last?.id == cardID else { return }
        await loadMore()
    }

    // MARK: - Filters

    /// View binding entry point. Selection is applied immediately so the chip
    /// row stays responsive; the page reload follows.
    func selectFilter(id: String) {
        guard prepareFilterSelection(id: id) else { return }
        Task { await loadFirstPage(clearingContent: true) }
    }

    /// Awaitable form of `selectFilter(id:)` for callers that need the reload.
    func applyFilter(id: String) async {
        guard prepareFilterSelection(id: id) else { return }
        await loadFirstPage(clearingContent: true)
    }

    private func prepareFilterSelection(id: String) -> Bool {
        guard id != selectedFilterID, filterItems.contains(where: { $0.id == id }) else {
            return false
        }
        selectedFilterID = id
        return true
    }

    // MARK: - Errors

    func dismissActionError() {
        actionError = nil
    }

    /// Banner Retry only ever retries the failed incremental page.
    func retryLoadMore() async {
        await loadMore()
    }

    // MARK: - Internals

    /// Group selection resets the cursor and content: pages from two different
    /// predicates must never interleave.
    private func loadFirstPage(clearingContent: Bool) async {
        guard let momentsRepo else { return }
        loadGeneration += 1
        let generation = loadGeneration
        if clearingContent {
            resetPagination()
        }
        if mediaCarousels.isEmpty { loadState = .loading }
        do {
            let people = try await loadPeople()
            let chips = try await loadFilterItems()
            let page = try await momentsRepo.feedPage(
                cursor: nil,
                limit: MomentLimits.defaultFeedPageSize,
                groupID: groupFilterID
            )
            // A newer filter selection started after this one — discard.
            guard generation == loadGeneration else { return }
            peopleByID = people
            applyFilterItems(chips)
            resetPagination()
            append(page)
            loadState = .loaded(mediaCarousels)
            actionError = nil
            lastSeenRevision = container?.storeRevision ?? lastSeenRevision
        } catch {
            guard generation == loadGeneration else { return }
            loadState = .failed(error)
        }
    }

    private func resetPagination() {
        mediaCarousels = []
        loadedMomentIDs = []
        nextCursor = nil
    }

    /// Dedupes by Moment id: a Moment whose activity bumped between pages can
    /// otherwise arrive twice, and `ForEach` traps on duplicate ids.
    private func append(_ page: MomentFeedPage) {
        let fresh = page.moments.filter { loadedMomentIDs.insert($0.id).inserted }
        mediaCarousels += MomentFeedCardBuilder.cards(from: fresh, people: peopleByID)
        nextCursor = page.nextCursor
    }

    /// Names and faces for tagged people come from the session's people cache;
    /// the feed DTO only carries ids.
    private func loadPeople() async throws -> [Person.ID: Person] {
        guard let container else { return peopleByID }
        let friends = try await container.friends.friends()
        let user = try await container.friends.currentUser()
        return Dictionary(uniqueKeysWithValues: (friends + [user]).map { ($0.id, $0) })
    }

    private func loadFilterItems() async throws -> [PushIvoryFilterItem] {
        guard let container else { return filterItems }
        let groups = try await container.groups.groups()
        let memberships = try await container.groups.memberships()
        return MomentFeedFilter.items(
            groups: groups,
            memberships: memberships,
            viewerID: container.currentUserID
        )
    }

    /// A group the viewer left (or that was deleted) can't stay selected —
    /// fall back to All so the feed keeps returning rows.
    private func applyFilterItems(_ items: [PushIvoryFilterItem]) {
        filterItems = items
        if !items.contains(where: { $0.id == selectedFilterID }) {
            selectedFilterID = MomentFeedFilter.allID
        }
    }
}

/// Feed › Pushes group chips: "All" plus the groups the viewer actively belongs
/// to, in group order (contract §7.8).
enum MomentFeedFilter {
    static let allID = "all"
    static let allTitle = "All"

    static var allItem: PushIvoryFilterItem {
        PushIvoryFilterItem(id: allID, title: allTitle)
    }

    static func items(
        groups: [FriendGroup],
        memberships: [GroupMembership],
        viewerID: Person.ID
    ) -> [PushIvoryFilterItem] {
        let activeGroupIDs = Set(
            memberships
                .filter { $0.personID == viewerID && $0.membershipStatus == .active }
                .map(\.groupID)
        )
        return [allItem] + groups
            .filter { activeGroupIDs.contains($0.id) }
            .map { PushIvoryFilterItem(id: $0.id, title: $0.name) }
    }
}
