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

        // Regression guard: live profiles must not collapse to empty scaffolding
        // (Set Status/Connect/Settings/Privacy cards would otherwise render empty).
        let profile = row.userProfile()
        XCTAssertEqual(profile.availabilityOptions, ProfileScaffolding.availabilityOptions)
        XCTAssertEqual(profile.activityVisibility, ProfileScaffolding.activityVisibility)
        XCTAssertEqual(profile.mapPreferences, ProfileScaffolding.mapPreferences)
        XCTAssertEqual(profile.closeFriends, ProfileScaffolding.closeFriends)
        XCTAssertEqual(profile.connectors, ProfileScaffolding.connectors)
    }

    func testProfileRowAppliesSettingsOverrides() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","first_name":"Alice",
         "handle":"alice","image_asset_path":null,"availability_choice":"free_now",
         "visibility_note":"","settings_activity_visibility":{"place":false},
         "settings_map_preferences":null,"settings_close_friends":{"pull-up":false}}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(ProfileRow.self, from: json)
        let profile = row.userProfile()

        // A stored override flips only its own id; unmentioned ids keep the
        // scaffolding default (both copy and enabled state).
        XCTAssertEqual(profile.activityVisibility.first { $0.id == "place" }?.isEnabled, false)
        XCTAssertEqual(
            profile.activityVisibility.first { $0.id == "activity" },
            ProfileScaffolding.activityVisibility.first { $0.id == "activity" }
        )
        // A null column (no overrides saved yet) falls back to scaffolding entirely.
        XCTAssertEqual(profile.mapPreferences, ProfileScaffolding.mapPreferences)
        XCTAssertEqual(profile.closeFriends.first { $0.id == "pull-up" }?.isEnabled, false)
    }

    func testSeedProfileSharesScaffoldingWithLiveProfile() {
        let seedProfile = SeedData.standardProfile()
        XCTAssertEqual(seedProfile.availabilityOptions, ProfileScaffolding.availabilityOptions)
        XCTAssertEqual(seedProfile.activityVisibility, ProfileScaffolding.activityVisibility)
        XCTAssertEqual(seedProfile.mapPreferences, ProfileScaffolding.mapPreferences)
        XCTAssertEqual(seedProfile.closeFriends, ProfileScaffolding.closeFriends)
        XCTAssertEqual(seedProfile.connectors, ProfileScaffolding.connectors)
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

    func testSharingPolicyRowMapsGlobalDefault() throws {
        let json = """
        {"id":"p1","owner_person_id":"11111111-1111-1111-1111-111111111111",
         "audience_type":"global_default","audience_id":null,
         "location_visibility":"exact","activity_visibility":"full",
         "availability_visibility":"full","expires_at":null}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(SharingPolicyRow.self, from: json)
        let p = row.policy()
        XCTAssertEqual(p.audienceType, .globalDefault)
        XCTAssertEqual(p.locationVisibility, .exact)
        XCTAssertNil(p.audienceID)
    }
}
