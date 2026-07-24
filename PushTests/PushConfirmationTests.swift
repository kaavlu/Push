import XCTest
@testable import Push

final class PushConfirmationTests: XCTestCase {
    func testConfigDefaultsToDestructiveRoleAndCancel() {
        let config = PushConfirmationConfig(
            title: "Sign out?",
            confirmTitle: "Sign Out"
        )
        XCTAssertEqual(config.confirmRole, .destructive)
        XCTAssertEqual(config.cancelTitle, "Cancel")
        XCTAssertNil(config.message)
    }

    func testConfigPreservesExplicitMessageAndRole() {
        let config = PushConfirmationConfig(
            title: "Delete Account?",
            message: "This cannot be undone.",
            confirmTitle: "Delete Account",
            confirmRole: .destructive,
            cancelTitle: "Keep account"
        )
        XCTAssertEqual(config.title, "Delete Account?")
        XCTAssertEqual(config.message, "This cannot be undone.")
        XCTAssertEqual(config.confirmTitle, "Delete Account")
        XCTAssertEqual(config.confirmRole, .destructive)
        XCTAssertEqual(config.cancelTitle, "Keep account")
    }

    func testRolesAreDistinct() {
        let roles: [PushConfirmationRole] = [.destructive, .primary]
        XCTAssertEqual(Set(roles.map { String(describing: $0) }).count, 2)
    }

    func testLayoutTokensArePositive() {
        XCTAssertGreaterThan(PushConfirmationLayout.maxCardWidth, 0)
        XCTAssertGreaterThan(PushConfirmationLayout.buttonHeight, 0)
        XCTAssertGreaterThan(PushConfirmationLayout.horizontalInset, 0)
        XCTAssertGreaterThan(PushOpacityTokens.dialogScrim, PushOpacityTokens.scrim)
    }
}
