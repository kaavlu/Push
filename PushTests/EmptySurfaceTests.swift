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
}
