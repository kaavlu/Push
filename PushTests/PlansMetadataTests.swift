// PushTests/PlansMetadataTests.swift
import XCTest
@testable import Push

final class PlansMetadataTests: XCTestCase {
    func testJoinedBothPresent() {
        XCTAssertEqual(PlansMetadata.joined(["Michigan", "North Park"]), "Michigan · North Park")
    }

    func testJoinedGroupMissingDropsSeparator() {
        XCTAssertEqual(PlansMetadata.joined(["", "North Park"]), "North Park")
    }

    func testJoinedLocationMissingDropsSeparator() {
        XCTAssertEqual(PlansMetadata.joined(["Michigan", ""]), "Michigan")
    }

    func testJoinedBothMissingIsEmpty() {
        XCTAssertEqual(PlansMetadata.joined(["", ""]), "")
    }

    func testJoinedTreatsWhitespaceOnlyValueAsMissing() {
        XCTAssertEqual(PlansMetadata.joined(["   ", "North Park"]), "North Park")
    }
}
