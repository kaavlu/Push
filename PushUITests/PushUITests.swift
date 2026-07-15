//
//  PushUITests.swift
//  PushUITests
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import XCTest

final class PushUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Ad-hoc verification for the push-card avatar fallback fix — not meant
    /// to stay in the suite long-term.
    func testPushesTabAvatarScreenshot() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Pushes"].tap()
        let screenshot = app.screenshot()
        let path = NSTemporaryDirectory() + "pushes_tab_avatars.png"
        try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: path))
        print("SCREENSHOT_SAVED_AT:\(path)")
    }

    /// Ad-hoc verification for the Active Push card Manage button — not meant
    /// to stay in the suite long-term.
    func testActivePushManageButtonScreenshot() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Pushes"].tap()
        let cardScreenshot = app.screenshot()
        try cardScreenshot.pngRepresentation.write(
            to: URL(fileURLWithPath: NSTemporaryDirectory() + "active_push_card.png")
        )
        let manageButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Manage'"))
        XCTAssertGreaterThan(manageButtons.count, 0, "Expected at least one Manage button")
        manageButtons.element(boundBy: manageButtons.count - 1).tap()
        let deckScreenshot = app.screenshot()
        try deckScreenshot.pngRepresentation.write(
            to: URL(fileURLWithPath: NSTemporaryDirectory() + "active_push_manage_deck.png")
        )
        print("SCREENSHOT_SAVED_AT:\(NSTemporaryDirectory())active_push_card.png")
        print("SCREENSHOT_SAVED_AT:\(NSTemporaryDirectory())active_push_manage_deck.png")
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
