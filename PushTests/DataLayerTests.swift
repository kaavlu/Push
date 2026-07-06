//
//  DataLayerTests.swift
//  PushTests
//

import XCTest
@testable import Push

final class DataLayerTests: XCTestCase {

    func testPersonDerivesDisplayNameAndInitials() {
        let person = Person(id: "chitty", firstName: "chitty", imageAssetPath: "assets/friends/chitty.png")
        XCTAssertEqual(person.displayName, "Chitty")
        XCTAssertEqual(person.initials, "CH")
    }

    func testFriendGroupDerivesInitials() {
        let group = FriendGroup(id: "michigan", name: "Michigan", imageAssetPath: nil)
        XCTAssertEqual(group.initials, "M")
    }

    func testAvailabilityStateIsCodable() throws {
        let data = try JSONEncoder().encode(FriendAvailabilityState.freeNow)
        let decoded = try JSONDecoder().decode(FriendAvailabilityState.self, from: data)
        XCTAssertEqual(decoded, .freeNow)
    }

    func testLoadStateExposesLoadedValue() {
        XCTAssertEqual(LoadState.loaded(3).value, 3)
        XCTAssertNil(LoadState<Int>.loading.value)
    }
}
