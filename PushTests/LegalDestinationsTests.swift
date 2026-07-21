import XCTest
@testable import Push

final class LegalDestinationsTests: XCTestCase {
    func testLegalDestinationsExposeTermsAndPrivacy() {
        XCTAssertEqual(LegalDestinations.all.map(\.id), [
            "terms-of-service",
            "privacy-policy",
        ])
        XCTAssertEqual(LegalDestinations.all.map(\.title), [
            "Terms of Service",
            "Privacy Policy",
        ])
    }

    func testLegalDestinationsUseDistinctHTTPSURLs() {
        let urls = LegalDestinations.all.map(\.url)

        XCTAssertTrue(urls.allSatisfy { $0.scheme == "https" })
        XCTAssertEqual(Set(urls).count, urls.count)
    }

    func testPlaceholderDestinationsRemainExplicitUntilHostingExists() {
        XCTAssertEqual(LegalDestinations.termsURL.host, "example.com")
        XCTAssertEqual(LegalDestinations.privacyURL.host, "example.com")
        XCTAssertTrue(LegalDestinations.termsURL.absoluteString.contains("push-legal=terms"))
        XCTAssertTrue(LegalDestinations.privacyURL.absoluteString.contains("push-legal=privacy"))
    }

    @MainActor
    func testProfileExposesCentralLegalDestinations() async {
        let viewModel = ProfileViewModel(container: AppDataContainer(seed: .standard()))

        XCTAssertEqual(viewModel.legalDestinations, LegalDestinations.all)
    }
}
