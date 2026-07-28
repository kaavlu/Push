import XCTest
@testable import Push

@MainActor
final class FeedViewModelTests: XCTestCase {
    func testDefaultTabIsPushesFirst() {
        let viewModel = FeedViewModel()
        XCTAssertEqual(viewModel.selectedTab, .pushes)
        XCTAssertEqual(FeedTab.allCases.first, .pushes)
        XCTAssertEqual(viewModel.selectedTabID, FeedTab.pushes.rawValue)
    }

    func testFilterDefaultsToAllAndPersistsAcrossTabSwitch() {
        let viewModel = FeedViewModel()
        XCTAssertEqual(viewModel.selectedFilterID, FeedFilterFixtures.allID)

        viewModel.selectFilter(id: "michigan")
        viewModel.selectTab(.now)
        XCTAssertEqual(viewModel.selectedTab, .now)
        XCTAssertEqual(viewModel.selectedFilterID, "michigan")

        viewModel.selectTab(.pushes)
        XCTAssertEqual(viewModel.selectedFilterID, "michigan")
    }

    func testSelectFilterIgnoresUnknownIDs() {
        let viewModel = FeedViewModel()
        viewModel.selectFilter(id: "not-a-real-filter")
        XCTAssertEqual(viewModel.selectedFilterID, FeedFilterFixtures.allID)
    }

    func testFixtureFiltersMatchIssueExamples() {
        let titles = FeedFilterFixtures.items.map(\.title)
        XCTAssertEqual(titles, ["All", "India", "Michigan", "Exec"])
        XCTAssertTrue(FeedFilterFixtures.items.allSatisfy { $0.count == nil })
    }

    func testPlaceholderCopyIsPresent() {
        XCTAssertFalse(EmptySurfaceCopy.feedPushesPlaceholderTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedPushesPlaceholderMessage.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedNowEmptyTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedNowEmptyMessage.isEmpty)
    }
}
