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

    func testFriendProfileRowsDecode() throws {
        let json = """
        [{"id":"22222222-2222-2222-2222-222222222222","first_name":"Bob","handle":"bob",
          "image_asset_path":null,"availability_choice":"free_now","visibility_note":""}]
        """.data(using: .utf8)!
        let rows = try JSONDecoder().decode([ProfileRow].self, from: json)
        XCTAssertEqual(rows.map { $0.person().displayName }, ["Bob"])
    }

    func testMembershipRowDefaultsSharingLevelToFull() throws {
        let json = """
        {"id":"m1","person_id":"22222222-2222-2222-2222-222222222222",
         "group_id":"g1","role":"member","membership_status":"active",
         "joined_at":"2026-07-12T00:00:00Z"}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(GroupMembershipRow.self, from: json)
        let m = row.membership()
        XCTAssertEqual(m.sharingLevel, .full)          // R3: policies are the visibility source, not membership.
        XCTAssertEqual(m.role, .member)
        XCTAssertEqual(m.membershipStatus, .active)
    }
}
