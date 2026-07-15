import Combine
import XCTest
@testable import Push

@MainActor
final class LiveDataStoreTests: XCTestCase {
    func testWarmLoadsFourResourcesConcurrentlyAndOnlyOnce() async throws {
        let loader = LiveDataLoaderSpy()
        let store = LiveDataStore(loader: loader)

        async let first: Void = store.warm()
        async let second: Void = store.warm()
        _ = try await (first, second)

        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1])
        XCTAssertEqual(loader.maximumConcurrentLoads, 4)
    }

    func testPreparedContainerRepositoriesShareSnapshotWithoutMoreReads() async throws {
        let loader = LiveDataLoaderSpy()
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")

        let user = try await container.friends.currentUser()
        let friends = try await container.friends.friends()
        let profile = try await container.profile.userProfile()
        let groups = try await container.groups.groups()
        let memberships = try await container.groups.memberships()
        let policies = try await container.sharing.allPolicies()
        XCTAssertEqual(user.id, "self")
        XCTAssertEqual(friends.map(\.id), ["friend"])
        XCTAssertEqual(profile.personID, "self")
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(memberships.count, 1)
        XCTAssertEqual(policies.count, 1)
        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1])
    }

    func testCurrentUserAndProfileUseAuthenticatedIDNotRowOrder() async throws {
        let loader = LiveDataLoaderSpy()
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "SELF")

        let user = try await container.friends.currentUser()
        let profile = try await container.profile.userProfile()
        let friends = try await container.friends.friends()

        XCTAssertEqual(user.id, "self")
        XCTAssertEqual(profile.personID, "self")
        XCTAssertEqual(friends.map(\.id), ["friend"])
    }

    func testPreparationFailsWhenAuthenticatedProfileIsMissing() async {
        let loader = LiveDataLoaderSpy()

        do {
            _ = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "missing")
            XCTFail("Expected missing authenticated profile to fail preparation")
        } catch {
            XCTAssertTrue(error is SupabaseRepositoryError)
        }
    }

    func testSnapshotNormalizesDuplicatePrimaryKeys() async throws {
        let loader = LiveDataLoaderSpy()
        loader.duplicateProfiles = true
        let store = LiveDataStore(loader: loader)

        try await store.warm()

        let ids = try await store.profiles().map(\.id)
        XCTAssertEqual(ids, ["friend", "self"])
    }

    func testSuccessfulWriteUpdatesSnapshotAndPublishesOneRevision() async throws {
        let loader = LiveDataLoaderSpy()
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")
        var revisions: [Int] = []
        let cancellable = container.onStoreChange { revisions.append($0) }

        try await container.profile.updateBasics(displayName: "Updated", handle: "@updated")

        let user = try await container.friends.currentUser()
        let profile = try await container.profile.userProfile()
        XCTAssertEqual(user.firstName, "Updated")
        XCTAssertEqual(profile.handle, "@updated")
        XCTAssertEqual(container.storeRevision, 1)
        XCTAssertEqual(revisions, [1])
        _ = cancellable
    }

    func testFailedWriteLeavesSnapshotAndRevisionUntouched() async throws {
        let loader = LiveDataLoaderSpy()
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")
        loader.writeError = TestFailure.expected

        do {
            try await container.friends.setCurrentUserAvailability(.busy)
            XCTFail("Expected write failure")
        } catch {}

        let profile = try await container.profile.userProfile()
        XCTAssertEqual(profile.chosenAvailability, .freeNow)
        XCTAssertEqual(container.storeRevision, 0)
    }
}

// Not `private`: reused by `SupabasePushRepositoryTests` for stateful push
// create/update/cancel/respond behavior.
@MainActor
final class LiveDataLoaderSpy: LiveDataLoading {
    var loadCounts = [0, 0, 0, 0]
    var maximumConcurrentLoads = 0
    var writeError: Error?
    var duplicateProfiles = false
    var pushRows: [PushRow] = []
    var responseRows: [PushResponseRow] = []
    /// Overridable so push-invitee tests can supply their own group rosters;
    /// defaults to the fixture the pre-existing store tests expect.
    var membershipRows = [GroupMembershipRow(
        id: "membership", person_id: "self", group_id: "group", role: "owner",
        membership_status: "active", joined_at: "2026-07-14T00:00:00Z"
    )]
    private var activeLoads = 0

    func loadProfiles() async throws -> [ProfileRow] {
        try await load(index: 0)
        var rows: [ProfileRow] = [.fixture(id: "friend", name: "Friend"), .fixture(id: "self", name: "Self")]
        if duplicateProfiles { rows.append(.fixture(id: "friend", name: "Duplicate")) }
        return rows
    }

    func loadGroups() async throws -> [GroupRow] {
        try await load(index: 1)
        return [GroupRow(id: "group", name: "Crew", image_asset_path: nil)]
    }

    func loadMemberships() async throws -> [GroupMembershipRow] {
        try await load(index: 2)
        return membershipRows
    }

    func loadPolicies() async throws -> [SharingPolicyRow] {
        try await load(index: 3)
        return [SharingPolicyRow(
            id: "policy", owner_person_id: "self", audience_type: "global_default",
            audience_id: nil, location_visibility: "full", activity_visibility: "full",
            availability_visibility: "full", expires_at: nil
        )]
    }

    func updateBasics(userID: String, displayName: String, handle: String) async throws -> ProfileRow {
        if let writeError { throw writeError }
        return .fixture(id: userID, name: displayName, handle: handle)
    }

    func updatePrivacy(userID: String, payload: ProfileSettingsPayload) async throws -> ProfileRow {
        if let writeError { throw writeError }
        return .fixture(id: userID, name: "Self")
    }

    func updateAvailability(userID: String, rawValue: String) async throws -> ProfileRow {
        if let writeError { throw writeError }
        return .fixture(id: userID, name: "Self", availability: rawValue)
    }

    private func load(index: Int) async throws {
        loadCounts[index] += 1
        activeLoads += 1
        maximumConcurrentLoads = max(maximumConcurrentLoads, activeLoads)
        try await Task.sleep(nanoseconds: 20_000_000)
        activeLoads -= 1
    }

    // MARK: - Pushes (stateful, so create/update/cancel/respond behavior can
    // be exercised end-to-end via `SupabasePushRepository` in other tests).

    func loadPushes() async throws -> [PushRow] { pushRows }
    func loadResponses() async throws -> [PushResponseRow] { responseRows }

    func insertPush(_ payload: PushInsertPayload) async throws -> PushRow {
        if let writeError { throw writeError }
        let row = PushRow(
            id: "push-\(pushRows.count + 1)", title: payload.title, group_id: payload.group_id,
            creator_id: payload.creator_id, created_at: "2026-07-14T00:00:00Z",
            updated_at: "2026-07-14T00:00:00Z", starts_at: payload.starts_at,
            has_explicit_time: payload.has_explicit_time, is_approximate_time: payload.is_approximate_time,
            expires_at: payload.expires_at, cancelled_at: nil, place_id: nil, place_is_suggested: false,
            state: "collecting", audience: payload.audience, note: payload.note,
            location_text: payload.location_text
        )
        pushRows.append(row)
        return row
    }

    func updatePush(id: String, payload: PushUpdatePayload) async throws -> PushRow {
        if let writeError { throw writeError }
        guard let index = pushRows.firstIndex(where: { $0.id == id }) else {
            throw SupabaseRepositoryError.notFound
        }
        let existing = pushRows[index]
        let updated = PushRow(
            id: existing.id, title: payload.title, group_id: payload.group_id,
            creator_id: existing.creator_id, created_at: existing.created_at, updated_at: payload.updated_at,
            starts_at: payload.starts_at, has_explicit_time: existing.has_explicit_time,
            is_approximate_time: existing.is_approximate_time, expires_at: payload.expires_at,
            cancelled_at: existing.cancelled_at, place_id: existing.place_id,
            place_is_suggested: existing.place_is_suggested, state: existing.state,
            audience: payload.audience, note: payload.note, location_text: payload.location_text
        )
        pushRows[index] = updated
        return updated
    }

    func cancelPush(id: String, payload: PushCancelPayload) async throws -> PushRow {
        if let writeError { throw writeError }
        guard let index = pushRows.firstIndex(where: { $0.id == id }) else {
            throw SupabaseRepositoryError.notFound
        }
        let existing = pushRows[index]
        let cancelled = PushRow(
            id: existing.id, title: existing.title, group_id: existing.group_id,
            creator_id: existing.creator_id, created_at: existing.created_at, updated_at: existing.updated_at,
            starts_at: existing.starts_at, has_explicit_time: existing.has_explicit_time,
            is_approximate_time: existing.is_approximate_time, expires_at: existing.expires_at,
            cancelled_at: payload.cancelled_at, place_id: existing.place_id,
            place_is_suggested: existing.place_is_suggested, state: existing.state,
            audience: existing.audience, note: existing.note, location_text: existing.location_text
        )
        pushRows[index] = cancelled
        return cancelled
    }

    func deletePush(id: String) async throws {
        if let writeError { throw writeError }
        pushRows.removeAll { $0.id == id }
        responseRows.removeAll { $0.push_id == id }
    }

    func insertResponses(_ payloads: [PushResponsePayload]) async throws {
        if let writeError { throw writeError }
        for payload in payloads {
            responseRows.append(PushResponseRow(
                id: "\(payload.push_id)-\(payload.person_id)", push_id: payload.push_id,
                person_id: payload.person_id, response: payload.response,
                responded_at: payload.responded_at, ready_state: "unknown"
            ))
        }
    }

    func upsertResponse(_ payload: PushResponsePayload) async throws {
        if let writeError { throw writeError }
        if let index = responseRows.firstIndex(
            where: { $0.push_id == payload.push_id && $0.person_id == payload.person_id }
        ) {
            let existing = responseRows[index]
            responseRows[index] = PushResponseRow(
                id: existing.id, push_id: existing.push_id, person_id: existing.person_id,
                response: payload.response, responded_at: payload.responded_at,
                ready_state: existing.ready_state
            )
        } else {
            responseRows.append(PushResponseRow(
                id: "\(payload.push_id)-\(payload.person_id)", push_id: payload.push_id,
                person_id: payload.person_id, response: payload.response,
                responded_at: payload.responded_at, ready_state: "unknown"
            ))
        }
    }

    func deleteResponses(pushID: String, personIDs: [String]) async throws {
        if let writeError { throw writeError }
        responseRows.removeAll { $0.push_id == pushID && personIDs.contains($0.person_id) }
    }

    // MARK: - Friendships

    var friendshipRows: [FriendshipRow] = [
        FriendshipRow(
            id: "friendship-self-friend",
            user_low: "friend",
            user_high: "self",
            status: "accepted",
            requested_by: nil,
            created_at: "2026-07-14T00:00:00Z"
        )
    ]
    var searchRows: [SearchProfileRow] = []

    func loadFriendships() async throws -> [FriendshipRow] { friendshipRows }

    func searchProfiles(query: String, limit: Int) async throws -> [SearchProfileRow] {
        let q = query.lowercased()
        return searchRows
            .filter {
                $0.handle.lowercased().contains(q) || $0.first_name.lowercased().contains(q)
            }
            .prefix(limit)
            .map { $0 }
    }

    func sendFriendRequest(targetUserID: String) async throws -> FriendshipRow {
        if let writeError { throw writeError }
        if let existing = friendshipRows.first(where: {
            $0.involves("self") && $0.involves(targetUserID)
        }) {
            return existing
        }
        let low = targetUserID < "self" ? targetUserID : "self"
        let high = targetUserID < "self" ? "self" : targetUserID
        let row = FriendshipRow(
            id: "friendship-\(friendshipRows.count + 1)",
            user_low: low,
            user_high: high,
            status: "pending",
            requested_by: "self",
            created_at: "2026-07-14T00:00:00Z"
        )
        friendshipRows.append(row)
        return row
    }

    func resolveFriendRequest(id: String, accept: Bool) async throws -> FriendshipRow {
        if let writeError { throw writeError }
        guard let index = friendshipRows.firstIndex(where: { $0.id == id }) else {
            throw SupabaseRepositoryError.notFound
        }
        let existing = friendshipRows[index]
        let updated = FriendshipRow(
            id: existing.id,
            user_low: existing.user_low,
            user_high: existing.user_high,
            status: accept ? "accepted" : "denied",
            requested_by: existing.requested_by,
            created_at: existing.created_at
        )
        friendshipRows[index] = updated
        return updated
    }

    func loadProfile(id: String) async throws -> ProfileRow {
        .fixture(id: id, name: id.capitalized)
    }
}

private enum TestFailure: Error { case expected }

private extension ProfileRow {
    static func fixture(
        id: String, name: String, handle: String = "@test", availability: String = "free_now"
    ) -> ProfileRow {
        ProfileRow(
            id: id, first_name: name, handle: handle, image_asset_path: nil,
            availability_choice: availability, visibility_note: "Visible",
            settings_activity_visibility: nil, settings_map_preferences: nil,
            settings_close_friends: nil
        )
    }
}
