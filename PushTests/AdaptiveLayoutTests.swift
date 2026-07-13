//
//  AdaptiveLayoutTests.swift
//  PushTests
//

import XCTest
@testable import Push

final class AdaptiveLayoutTests: XCTestCase {
    func testLayoutTierThresholdsUseContainerWidth() {
        XCTAssertEqual(PushAdaptiveLayout(containerWidth: 360).tier, .compact)
        XCTAssertEqual(PushAdaptiveLayout(containerWidth: 390).tier, .standard)
        XCTAssertEqual(PushAdaptiveLayout(containerWidth: 430).tier, .large)
    }

    func testLargeTierPreservesReferenceMetrics() {
        let layout = PushAdaptiveLayout(containerWidth: 430)

        XCTAssertEqual(layout.pageHorizontalPadding, 18)
        XCTAssertEqual(layout.cardCornerRadius, 26)
        XCTAssertEqual(layout.avatarLarge, 112)
        XCTAssertEqual(layout.puckScale, 1.0)
    }

    func testCompactTierOnlyReducesDecorativeMetrics() {
        let compact = PushAdaptiveLayout(containerWidth: 360)

        XCTAssertEqual(compact.controlSize, 44)
        XCTAssertLessThan(compact.pageHorizontalPadding, PushAdaptiveLayout.reference.pageHorizontalPadding)
        XCTAssertLessThan(compact.avatarLarge, PushAdaptiveLayout.reference.avatarLarge)
        XCTAssertLessThan(compact.puckScale, PushAdaptiveLayout.reference.puckScale)
    }
}
