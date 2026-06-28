//
//  PushTests.swift
//  PushTests
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import XCTest
@testable import Push

final class PushTests: XCTestCase {

    func testBottomNavigationItemsExposePlaceholderTabs() throws {
        let items = BottomNavigationItem.allCases

        XCTAssertEqual(items.map(\.title), ["Map", "Group", "+", "Feed", "Plans"])
        XCTAssertEqual(items.map(\.systemImageName), [
            "map.fill",
            "person.2.fill",
            "plus",
            "list.bullet",
            "calendar"
        ])
        XCTAssertEqual(items.filter(\.isPrimaryAction), [.create])
    }

    func testFriendGroupFiltersExposeMockDropdownOptions() throws {
        XCTAssertEqual(FriendGroupFilter.allCases.map(\.title), [
            "All Friends",
            "College Friends",
            "Gym Crew",
            "Roommates",
            "NYC Friends"
        ])
    }

    func testGlassStyleTokensExposeConsistentMaterialValues() throws {
        XCTAssertEqual(PushGlassStyle.materialPresenceOpacity, 0.72)
        XCTAssertEqual(PushGlassStyle.tintOpacity, 0.24)
        XCTAssertEqual(PushGlassStyle.strokeOpacity, 0.62)
        XCTAssertEqual(PushGlassStyle.strokeWidth, 0.8)
        XCTAssertEqual(PushGlassStyle.shadowOpacity, 0.24)
        XCTAssertEqual(PushGlassStyle.shadowRadius, 26)
        XCTAssertEqual(PushGlassStyle.shadowYOffset, 12)
    }

    func testControlStyleTokensExposeSharedAccentBehavior() throws {
        XCTAssertEqual(PushControlStyle.activeFillOpacity, 1)
        XCTAssertEqual(PushControlStyle.inactiveForegroundOpacity, 0.7)
        XCTAssertEqual(PushControlStyle.primaryStrokeOpacity, 0.72)
        XCTAssertEqual(PushControlStyle.primaryGlowOpacity, 0.34)
    }

}
