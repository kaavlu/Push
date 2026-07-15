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

    func testPushRowDecodesFractionalTimestampsAndBridgesAudience() throws {
        let json = """
        {"id":"push1","title":"Beach day","group_id":"g1","creator_id":"creator1",
         "created_at":"2026-07-13T11:24:18.230123+00:00","updated_at":"2026-07-13T11:24:18.230123+00:00",
         "starts_at":"2026-07-14T18:00:00+00:00","has_explicit_time":true,"is_approximate_time":false,
         "expires_at":"2026-07-15T00:00:00+00:00","cancelled_at":null,"place_id":null,
         "place_is_suggested":false,"state":"collecting","audience":"invitees_only",
         "note":"Bring towels","location_text":"The pier"}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(PushRow.self, from: json)
        let plan = row.pushPlan()

        // "invitees_only" isn't a valid Swift identifier, so this exercises
        // the explicit audience bridge rather than `init(rawValue:)`.
        XCTAssertEqual(plan.audience, .inviteesOnly)
        XCTAssertEqual(plan.state, .collecting)
        XCTAssertNil(plan.cancelledAt)
        // Fractional-second timestamps must not fall back to the epoch sentinel.
        XCTAssertNotEqual(plan.startsAt, Date(timeIntervalSince1970: 0))
    }

    func testPushRowMapsGroupAudienceAndCancelledAt() throws {
        let json = """
        {"id":"push2","title":"Movie night","group_id":null,"creator_id":"creator1",
         "created_at":"2026-07-13T00:00:00Z","updated_at":"2026-07-13T00:00:00Z",
         "starts_at":"2026-07-14T00:00:00Z","has_explicit_time":true,"is_approximate_time":false,
         "expires_at":"2026-07-14T06:00:00Z","cancelled_at":"2026-07-13T12:00:00Z","place_id":null,
         "place_is_suggested":false,"state":"locked","audience":"group",
         "note":null,"location_text":null}
        """.data(using: .utf8)!
        let plan = try JSONDecoder().decode(PushRow.self, from: json).pushPlan()

        XCTAssertEqual(plan.audience, .group)
        XCTAssertEqual(plan.state, .locked)
        XCTAssertNotNil(plan.cancelledAt)
    }

    func testPushResponseRowBridgesReadyStateAndHandlesNilRespondedAt() throws {
        let json = """
        {"id":"r1","push_id":"push1","person_id":"bob","response":"pending",
         "responded_at":null,"ready_state":"needs_ride"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PushResponseRow.self, from: json).pushResponse()

        XCTAssertEqual(response.response, .pending)
        XCTAssertNil(response.respondedAt)
        // "needs_ride" isn't a valid Swift identifier, so this exercises the
        // explicit readyState bridge rather than `init(rawValue:)`.
        XCTAssertEqual(response.readyState, .needsRide)
    }

    // Regression guard: `LiveDataLoaderSpy`-based repository tests hand Swift
    // structs directly to a fake loader and never touch `JSONEncoder`, so a
    // bug in `Encodable` synthesis (e.g. an omitted vs. `null` key) would
    // pass there but break the real PostgREST bulk insert. This encodes for
    // real and checks the wire shape.
    func testPushResponsePayloadAlwaysEmitsRespondedAtKeyEvenWhenNil() throws {
        let responded = PushResponsePayload(
            push_id: "push1", person_id: "creator1", response: "in", responded_at: "2026-07-14T00:00:00Z"
        )
        let pending = PushResponsePayload(
            push_id: "push1", person_id: "invitee1", response: "pending", responded_at: nil
        )
        let data = try JSONEncoder().encode([responded, pending])
        let objects = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        // PostgREST rejects a bulk insert (PGRST102) unless every object in
        // the array has an identical key set — an omitted key (rather than
        // an explicit `null`) for the pending row would break real requests
        // even though this test's fake loader can't detect it.
        XCTAssertEqual(Set(objects[0].keys), Set(objects[1].keys))
        XCTAssertTrue(objects[1].keys.contains("responded_at"))
        XCTAssertTrue(objects[1]["responded_at"] is NSNull)
    }

    // Regression guard: switching a managed push from a group to an
    // individual sets `group_id` to nil in the draft. If `PushUpdatePayload`
    // relies on synthesized `Encodable` (which uses `encodeIfPresent`), the
    // key is *omitted* from the wire payload instead of sent as `null`, so
    // PostgREST leaves the push's previous `group_id` untouched — the
    // group→person switch silently fails to persist. Encoding for real (not
    // handing the struct to a fake loader) is required to catch this.
    func testPushUpdatePayloadEmitsNullGroupIDWhenClearingGroup() throws {
        let payload = PushUpdatePayload(
            title: "Dinner", group_id: nil, starts_at: "2026-07-15T17:00:00Z",
            expires_at: "2026-07-15T23:00:00Z", audience: "invitees_only",
            note: nil, location_text: nil, updated_at: "2026-07-15T17:09:00Z"
        )
        let data = try JSONEncoder().encode(payload)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertTrue(object.keys.contains("group_id"), "group_id must be sent explicitly, not omitted")
        XCTAssertTrue(object["group_id"] is NSNull, "a cleared group must be written as null, not skipped")
    }

    func testPushResponseRowDecodesFractionalRespondedAt() throws {
        let json = """
        {"id":"r2","push_id":"push1","person_id":"carol","response":"in",
         "responded_at":"2026-07-13T11:24:18.230123+00:00","ready_state":"ready_now"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PushResponseRow.self, from: json).pushResponse()

        XCTAssertEqual(response.response, .in)
        XCTAssertEqual(response.readyState, .readyNow)
        XCTAssertNotNil(response.respondedAt)
    }
}
