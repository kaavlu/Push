import XCTest
@testable import Push

final class SupabaseConfigTests: XCTestCase {
    func testValidProductionHostPasses() {
        let url = URL(string: "https://tzzvwjhvjduyqywlszqc.supabase.co")!

        XCTAssertTrue(SupabaseConfig.isProductionHost(url))
    }

    func testLocalhostFailsProductionCheck() {
        let url = URL(string: "http://localhost:54321")!

        XCTAssertFalse(SupabaseConfig.isProductionHost(url))
    }

    func testEmptyHostFailsProductionCheck() {
        let url = URL(string: "file:///dev/null")!

        XCTAssertFalse(SupabaseConfig.isProductionHost(url))
    }
}
