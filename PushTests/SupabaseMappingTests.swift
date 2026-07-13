import XCTest
@testable import Push

final class SupabaseMappingTests: XCTestCase {
    func testProfileRowMapsToDomain() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","first_name":"Alice",
         "handle":"alice","image_asset_path":null,"availability_choice":"free_now",
         "visibility_note":""}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(ProfileRow.self, from: json)
        XCTAssertEqual(row.person().id, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(row.person().firstName, "Alice")
        XCTAssertEqual(row.userProfile().handle, "alice")
    }
}
