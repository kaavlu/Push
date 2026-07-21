import XCTest
@testable import Push

final class EmptySurfaceTests: XCTestCase {
    func testCopyIsHonestAndDistinct() {
        XCTAssertFalse(EmptySurfaceCopy.mapEmptyTitle.isEmpty)
        XCTAssertFalse(EmptySurfaceCopy.feedDeferredTitle.isEmpty)
        XCTAssertNotEqual(EmptySurfaceCopy.mapEmptyTitle, EmptySurfaceCopy.failedTitle(surface: "map"))
        XCTAssertEqual(EmptySurfaceCopy.addFriendsAction, "Add friends")
        XCTAssertEqual(EmptySurfaceCopy.calendarEmptyFooter, "No hangouts this week")
    }

    func testSurfacePhasesAreDistinct() {
        let phases: [SurfaceContentPhase] = [.loading, .empty, .failed, .content, .deferred]
        XCTAssertEqual(Set(phases.map { String(describing: $0) }).count, 5)
    }

    @MainActor
    func testMapEmptyPhaseForEmptyGraph() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .emptyGraph()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .empty)
        XCTAssertFalse(viewModel.hasFriendMapContent)
    }

    @MainActor
    func testMapContentPhaseForStandardSeed() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .content)
        XCTAssertTrue(viewModel.hasFriendMapContent)
    }

    @MainActor
    func testMapFailedPhaseOnRepositoryError() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = MapViewModel(
            friends: ThrowingFriendRepository(),
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
        await viewModel.load()
        XCTAssertEqual(viewModel.surfacePhase, .failed)
    }
}
