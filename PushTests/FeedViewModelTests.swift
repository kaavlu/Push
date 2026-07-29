//
//  FeedViewModelTests.swift
//  PushTests
//
//  Feed shell state plus the repository-backed Feed › Pushes stream
//  (Issue #125 / S6): loading, empty, failure + retry, group filtering,
//  cursor pagination, refresh, and mock/live isolation.
//

import Foundation
import XCTest
@testable import Push

@MainActor
final class FeedViewModelTests: XCTestCase {

    private let northPark = "moment-north-park"
    private let blueBottle = "moment-blue-bottle"
    private let crunch = "moment-crunch"

    // MARK: - Shell

    func testDefaultTabIsPushesFirst() {
        let viewModel = FeedViewModel(carousels: [])
        XCTAssertEqual(viewModel.selectedTab, .pushes)
        XCTAssertEqual(FeedTab.allCases.first, .pushes)
        XCTAssertEqual(viewModel.selectedTabID, FeedTab.pushes.rawValue)
    }

    func testFilterDefaultsToAllAndPersistsAcrossTabSwitch() async {
        let container = AppDataContainer(seed: .standard())
        joinGroup("india", in: container)
        let viewModel = FeedViewModel(container: container)
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.selectedFilterID, MomentFeedFilter.allID)

        await viewModel.applyFilter(id: "india")
        viewModel.selectTab(.now)
        XCTAssertEqual(viewModel.selectedTab, .now)
        XCTAssertEqual(viewModel.selectedFilterID, "india")

        viewModel.selectTab(.pushes)
        XCTAssertEqual(viewModel.selectedFilterID, "india")
    }

    func testSelectFilterIgnoresUnknownIDs() async {
        let viewModel = FeedViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.initialLoad?.value

        await viewModel.applyFilter(id: "not-a-real-filter")
        XCTAssertEqual(viewModel.selectedFilterID, MomentFeedFilter.allID)
    }

    func testPlaceholderCopyIsPresent() {
        XCTAssertFalse(MomentFeedCopy.emptyTitle.isEmpty)
        XCTAssertFalse(MomentFeedCopy.emptyMessage.isEmpty)
        XCTAssertFalse(MomentFeedCopy.loadMoreFailed.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedNowEmptyTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedNowEmptyMessage.isEmpty)
    }

    // MARK: - Loading

    func testMockFeedLoadsMomentsFromTheRepositoryNotFixtures() async {
        let container = AppDataContainer(seed: .standard())
        let viewModel = FeedViewModel(container: container)
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.contentPhase, .content)
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), [northPark, blueBottle, crunch])
        let fixtureIDs = Set(FeedMediaCarouselFixtures.feedPushesPreviewStack.map(\.id))
        XCTAssertTrue(Set(viewModel.mediaCarousels.map(\.id)).isDisjoint(with: fixtureIDs))
    }

    func testCardsCarryMappedMediaPeopleAndCapabilities() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = FeedViewModel(container: container)
        await viewModel.initialLoad?.value

        let card = try XCTUnwrap(viewModel.mediaCarousels.first { $0.id == self.northPark })
        // Seed North Park has three media items and three tagged people.
        XCTAssertEqual(card.items.count, 3)
        XCTAssertEqual(card.participants.count, 3)
        XCTAssertEqual(card.participants.first?.id, container.currentUserID)
        XCTAssertFalse(card.title.isEmpty)
        XCTAssertFalse(card.locationDateMetaLine.isEmpty)
        // Creator is tagged, so Add yours is available.
        XCTAssertTrue(card.canAddYours)

        // Viewer-only Moment: no Add yours affordance.
        let watched = try XCTUnwrap(viewModel.mediaCarousels.first { $0.id == self.crunch })
        XCTAssertFalse(watched.canAddYours)
    }

    func testEmptyRepositoryShowsTheEmptySurfaceNotFixtures() async {
        let viewModel = await makeViewModel(repository: FakeMomentRepository(pages: [.empty]))

        XCTAssertEqual(viewModel.contentPhase, .empty)
        XCTAssertTrue(viewModel.mediaCarousels.isEmpty)
    }

    func testInitialFailureShowsFailedPhaseAndRetryRecovers() async {
        let repository = FakeMomentRepository(pages: [page(ids: ["a", "b"], hasMore: false)])
        repository.failNextFeedPage = true
        let viewModel = await makeViewModel(repository: repository)

        XCTAssertEqual(viewModel.contentPhase, .failed)
        XCTAssertTrue(viewModel.mediaCarousels.isEmpty)

        await viewModel.load()
        XCTAssertEqual(viewModel.contentPhase, .content)
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a", "b"])
    }

    // MARK: - Pagination

    func testAdditionalPagesAppendWithoutDuplicatesAndStopAtTheLastPage() async {
        let repository = FakeMomentRepository(pages: [
            page(ids: ["a", "b"], hasMore: true),
            // "b" repeats: its activity bumped between pages.
            page(ids: ["b", "c"], hasMore: true),
            page(ids: ["d"], hasMore: false)
        ])
        let viewModel = await makeViewModel(repository: repository)

        await viewModel.loadMore()
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a", "b", "c"])
        XCTAssertTrue(viewModel.hasMorePages)

        await viewModel.loadMore()
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a", "b", "c", "d"])
        XCTAssertFalse(viewModel.hasMorePages)

        // Cursor is exhausted — no further repository call.
        let callsBefore = repository.feedCalls.count
        await viewModel.loadMore()
        XCTAssertEqual(repository.feedCalls.count, callsBefore)
    }

    func testPaginationPassesTheCursorFromThePreviousPage() async throws {
        let repository = FakeMomentRepository(pages: [
            page(ids: ["a"], hasMore: true),
            page(ids: ["b"], hasMore: false)
        ])
        let viewModel = await makeViewModel(repository: repository)
        repository.feedCalls.removeAll()

        await viewModel.loadMore()

        let call = try XCTUnwrap(repository.feedCalls.first)
        XCTAssertEqual(call.cursor?.momentID, "a")
        XCTAssertEqual(call.limit, MomentLimits.defaultFeedPageSize)
    }

    func testPaginationFailureKeepsContentAndRetrySucceeds() async {
        let repository = FakeMomentRepository(pages: [
            page(ids: ["a"], hasMore: true),
            page(ids: ["b"], hasMore: false)
        ])
        let viewModel = await makeViewModel(repository: repository)

        repository.failNextFeedPage = true
        await viewModel.loadMore()

        // Recoverable: cards stay, banner offers Retry.
        XCTAssertEqual(viewModel.contentPhase, .content)
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a"])
        XCTAssertEqual(viewModel.actionError?.message, MomentFeedCopy.loadMoreFailed)

        await viewModel.retryLoadMore()
        XCTAssertNil(viewModel.actionError)
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a", "b"])
    }

    func testLoadMoreOnlyTriggersForTheLastCard() async {
        let repository = FakeMomentRepository(pages: [
            page(ids: ["a", "b"], hasMore: true),
            page(ids: ["c"], hasMore: false)
        ])
        let viewModel = await makeViewModel(repository: repository)

        await viewModel.loadMoreIfNeeded(after: "a")
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a", "b"])

        await viewModel.loadMoreIfNeeded(after: "b")
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["a", "b", "c"])
    }

    // MARK: - Refresh

    func testRefreshReplacesTheSnapshotFromPageOne() async {
        let repository = FakeMomentRepository(pages: [
            page(ids: ["a", "b"], hasMore: true),
            page(ids: ["c"], hasMore: false)
        ])
        let viewModel = await makeViewModel(repository: repository)
        await viewModel.loadMore()
        XCTAssertEqual(viewModel.mediaCarousels.count, 3)

        // Server state moved on: refresh must take page one as the new truth.
        repository.pages = [page(ids: ["z"], hasMore: false)]
        await viewModel.refresh()

        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["z"])
        XCTAssertFalse(viewModel.hasMorePages)
    }

    // MARK: - Group filters

    func testFilterChipsComeFromTheViewersActiveGroups() async {
        let container = AppDataContainer(seed: .standard())
        joinGroup("india", in: container)
        let viewModel = FeedViewModel(container: container)
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.filterItems.first?.id, MomentFeedFilter.allID)
        XCTAssertTrue(viewModel.filterItems.contains { $0.id == "india" })
        // Groups the viewer is not an active member of never become chips.
        let ids = Set(viewModel.filterItems.map(\.id))
        XCTAssertEqual(ids.subtracting([MomentFeedFilter.allID]), ["india"])
    }

    func testGroupSelectionQueriesThatGroupAndResetsContent() async throws {
        let container = AppDataContainer(seed: .standard())
        joinGroup("india", in: container)
        let repository = FakeMomentRepository(pages: [
            page(ids: ["a", "b"], hasMore: true),
            page(ids: ["c"], hasMore: false)
        ])
        let viewModel = await makeViewModel(repository: repository, container: container)
        XCTAssertTrue(viewModel.hasMorePages)
        repository.feedCalls.removeAll()
        repository.pages = [page(ids: ["group-only"], hasMore: false)]

        await viewModel.applyFilter(id: "india")

        let call = try XCTUnwrap(repository.feedCalls.first)
        XCTAssertEqual(call.groupID, "india")
        // Cursor and content reset — pages from two predicates never interleave.
        XCTAssertNil(call.cursor)
        XCTAssertEqual(viewModel.mediaCarousels.map(\.id), ["group-only"])
        XCTAssertFalse(viewModel.hasMorePages)
    }

    func testAllFilterSendsNoGroupPredicate() async throws {
        let container = AppDataContainer(seed: .standard())
        joinGroup("india", in: container)
        let repository = FakeMomentRepository(pages: [page(ids: ["a"], hasMore: false)])
        let viewModel = await makeViewModel(repository: repository, container: container)
        await viewModel.applyFilter(id: "india")
        repository.feedCalls.removeAll()

        await viewModel.applyFilter(id: MomentFeedFilter.allID)

        let call = try XCTUnwrap(repository.feedCalls.first)
        XCTAssertNil(call.groupID)
    }

    func testSelectingTheSameFilterDoesNotReload() async {
        let repository = FakeMomentRepository(pages: [page(ids: ["a"], hasMore: false)])
        let viewModel = await makeViewModel(repository: repository)
        repository.feedCalls.removeAll()

        await viewModel.applyFilter(id: MomentFeedFilter.allID)

        XCTAssertTrue(repository.feedCalls.isEmpty)
    }

    // MARK: - Live isolation

    func testLiveContainerFeedIsEmptyRatherThanFixtureBacked() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = []
        let container = try await AppDataContainer.prepareLive(
            loader: loader, currentUserID: "self"
        )
        let viewModel = FeedViewModel(container: container)
        await viewModel.initialLoad?.value

        XCTAssertEqual(viewModel.contentPhase, .empty)
        XCTAssertTrue(viewModel.mediaCarousels.isEmpty)
        // Chips come from the live store's groups, never from the shell fixtures.
        XCTAssertEqual(viewModel.filterItems.first?.id, MomentFeedFilter.allID)
        let fixtureTitles = Set(FeedFilterFixtures.items.dropFirst().map(\.title))
        XCTAssertTrue(Set(viewModel.filterItems.map(\.title)).isDisjoint(with: fixtureTitles))
    }

    /// Mock and live must render one Moment identically: `LocalMomentRepository`
    /// and a decoded `feed_moments` DTO for the same album produce equal cards.
    func testMockAndLiveProjectionsProduceTheSameCardForOneMoment() async throws {
        let container = AppDataContainer(seed: MomentParityFixture.seed())
        let viewModel = FeedViewModel(container: container)
        await viewModel.initialLoad?.value

        let mockCard = try XCTUnwrap(viewModel.mediaCarousels.first)

        let row = try JSONDecoder().decode(
            MomentRow.self, from: Data(MomentParityFixture.feedJSON().utf8)
        )
        let people = try await peopleByID(in: container)
        let liveCard = MomentFeedCardBuilder.card(
            from: row.summary(viewerID: container.currentUserID),
            people: people
        )

        XCTAssertEqual(mockCard, liveCard)
    }

    private func peopleByID(in container: AppDataContainer) async throws -> [Person.ID: Person] {
        let friends = try await container.friends.friends()
        let user = try await container.friends.currentUser()
        return Dictionary(uniqueKeysWithValues: (friends + [user]).map { ($0.id, $0) })
    }

    // MARK: - Helpers

    /// Awaits the initializer's bootstrap load so no stray task lands mid-test.
    private func makeViewModel(
        repository: MomentRepository,
        container: AppDataContainer? = nil
    ) async -> FeedViewModel {
        let viewModel = FeedViewModel(
            container: container ?? AppDataContainer(seed: .standard()),
            moments: repository
        )
        await viewModel.initialLoad?.value
        return viewModel
    }

    private func joinGroup(_ groupID: FriendGroup.ID, in container: AppDataContainer) {
        container.database.memberships.append(
            GroupMembership(
                id: "membership-\(groupID)-\(container.currentUserID)",
                personID: container.currentUserID,
                groupID: groupID,
                role: .member,
                sharingLevel: .full,
                membershipStatus: .active,
                joinedAt: Date()
            )
        )
    }

    private func page(ids: [Moment.ID], hasMore: Bool) -> MomentFeedPage {
        let summaries = ids.map(FeedTestMoment.summary(id:))
        return MomentFeedPage(
            moments: summaries,
            nextCursor: hasMore
                ? summaries.last.map {
                    MomentFeedCursor(
                        lastActivityAt: $0.moment.lastActivityAt, momentID: $0.moment.id
                    )
                }
                : nil
        )
    }
}
