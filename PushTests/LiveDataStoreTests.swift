import Combine
import XCTest
@testable import Push

@MainActor
final class LiveDataStoreTests: XCTestCase {
    func testWarmLoadsSevenResourcesConcurrentlyAndOnlyOnce() async throws {
        let loader = LiveDataLoaderSpy()
        let store = LiveDataStore(loader: loader)

        async let first: Void = store.warm()
        async let second: Void = store.warm()
        _ = try await (first, second)

        // profiles, groups, memberships, policies, pushes, responses, presence
        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1, 1])
        XCTAssertEqual(loader.maximumConcurrentLoads, 7)
    }

    func testPreparedContainerRepositoriesShareSnapshotWithoutMoreReads() async throws {
        let loader = LiveDataLoaderSpy()
        loader.pushRows = [Self.samplePushRow(id: "push-1", creator: "self")]
        loader.responseRows = [Self.sampleResponseRow(pushID: "push-1", personID: "self")]
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")

        let user = try await container.friends.currentUser()
        let friends = try await container.friends.friends()
        let profile = try await container.profile.userProfile()
        let groups = try await container.groups.groups()
        let memberships = try await container.groups.memberships()
        let policies = try await container.sharing.allPolicies()
        let plans = try await container.pushes.activePlans()
        let responses = try await container.pushes.responses()
        XCTAssertEqual(user.id, "self")
        XCTAssertEqual(friends.map(\.id), ["friend"])
        XCTAssertEqual(profile.personID, "self")
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(memberships.count, 1)
        XCTAssertEqual(policies.count, 1)
        XCTAssertEqual(plans.map(\.id), ["push-1"])
        XCTAssertEqual(responses.map(\.personID), ["self"])
        // Warm already loaded all seven; tab/repo reads must not re-hit the network.
        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1, 1])
    }

    func testNotifyPushesChangedInvalidatesPushSnapshot() async throws {
        let loader = LiveDataLoaderSpy()
        loader.pushRows = [Self.samplePushRow(id: "push-1", creator: "self")]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        XCTAssertEqual(loader.loadCounts[LiveDataLoaderSpy.Index.pushes], 1)

        _ = try await store.pushes()
        XCTAssertEqual(
            loader.loadCounts[LiveDataLoaderSpy.Index.pushes], 1,
            "cached push read should not re-fetch"
        )

        store.notifyPushesChanged()
        loader.pushRows = [
            Self.samplePushRow(id: "push-1", creator: "self"),
            Self.samplePushRow(id: "push-2", creator: "friend")
        ]
        let refreshed = try await store.pushes()
        XCTAssertEqual(refreshed.map(\.id), ["push-1", "push-2"])
        XCTAssertEqual(loader.loadCounts[LiveDataLoaderSpy.Index.pushes], 2)
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

    func testRefreshClearsCachesAndRefetchesOnce() async throws {
        let loader = LiveDataLoaderSpy()
        loader.pushRows = [Self.samplePushRow(id: "push-1", creator: "self")]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1, 1])

        loader.pushRows = [
            Self.samplePushRow(id: "push-1", creator: "self"),
            Self.samplePushRow(id: "push-2", creator: "friend")
        ]
        var revisions: [Int] = []
        let sub = store.onChange { revisions.append($0) }

        try await store.refresh()

        let pushes = try await store.pushes()
        XCTAssertEqual(pushes.map(\.id), ["push-1", "push-2"])
        XCTAssertEqual(loader.loadCounts, [2, 2, 2, 2, 2, 2, 2])
        XCTAssertEqual(revisions, [1])
        XCTAssertEqual(store.revision, 1)
        _ = sub
    }

    func testConcurrentRefreshSharesOneInFlight() async throws {
        let loader = LiveDataLoaderSpy()
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        loader.loadCounts = [0, 0, 0, 0, 0, 0, 0]

        async let a: Void = store.refresh()
        async let b: Void = store.refresh()
        _ = try await (a, b)

        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1, 1])
        XCTAssertEqual(store.revision, 1)
    }

    func testFailedRefreshLeavesCacheAndRevisionUntouched() async throws {
        let loader = LiveDataLoaderSpy()
        loader.pushRows = [Self.samplePushRow(id: "push-1", creator: "self")]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        let before = store.revision
        loader.shouldFailLoads = true

        do {
            try await store.refresh()
            XCTFail("expected throw")
        } catch {
            // expected
        }

        loader.shouldFailLoads = false
        let pushes = try await store.pushes()
        XCTAssertEqual(pushes.map(\.id), ["push-1"])
        XCTAssertEqual(store.revision, before)
    }

    func testRefreshSessionOnPreparedContainerRefetches() async throws {
        let loader = LiveDataLoaderSpy()
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")
        XCTAssertEqual(loader.loadCounts, [1, 1, 1, 1, 1, 1, 1])
        try await container.refreshSession()
        XCTAssertEqual(loader.loadCounts, [2, 2, 2, 2, 2, 2, 2])
    }

    func testPresenceIncludedInWarmAndSurvivesFailedRefresh() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            .fixture(userID: "friend", lat: 37.77, lng: -122.42)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()

        let presence = try await store.currentPresence()
        XCTAssertEqual(presence.map(\.user_id), ["friend"])
        XCTAssertEqual(loader.loadCounts[LiveDataLoaderSpy.Index.presence], 1)

        loader.shouldFailLoads = true
        do {
            try await store.refresh()
            XCTFail("expected throw")
        } catch {}

        loader.shouldFailLoads = false
        let restored = try await store.currentPresence()
        XCTAssertEqual(restored.map(\.user_id), ["friend"])
        XCTAssertEqual(
            loader.loadCounts[LiveDataLoaderSpy.Index.presence], 1,
            "failed refresh must restore cache without re-fetch"
        )
    }

    func testNotifyPresenceChangedInvalidatesAndBumpsOneRevision() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            .fixture(userID: "friend", lat: 37.77, lng: -122.42)
        ]
        let store = LiveDataStore(loader: loader)
        try await store.warm()
        var revisions: [Int] = []
        let sub = store.onChange { revisions.append($0) }

        store.notifyPresenceChanged()
        loader.presenceRows = [
            .fixture(userID: "friend", lat: 37.78, lng: -122.41),
            .fixture(userID: "self", lat: 37.76, lng: -122.43)
        ]
        let refreshed = try await store.currentPresence()
        XCTAssertEqual(Set(refreshed.map(\.user_id)), Set(["friend", "self"]))
        XCTAssertEqual(loader.loadCounts[LiveDataLoaderSpy.Index.presence], 2)
        XCTAssertEqual(revisions, [1])
        XCTAssertEqual(store.revision, 1)
        _ = sub
    }

    func testRefreshSessionOnMockIsNoOp() async throws {
        let container = AppDataContainer(seed: .standard())
        let before = container.storeRevision
        try await container.refreshSession()
        XCTAssertEqual(container.storeRevision, before)
    }
}

// Not `private`: reused by `SupabasePushRepositoryTests` for stateful push
// create/update/cancel/respond behavior.
@MainActor
final class LiveDataLoaderSpy: LiveDataLoading {
    enum Index {
        static let profiles = 0
        static let groups = 1
        static let memberships = 2
        static let policies = 3
        static let pushes = 4
        static let responses = 5
        static let presence = 6
        static let count = 7
    }

    /// profiles, groups, memberships, policies, pushes, responses, presence
    var loadCounts = Array(repeating: 0, count: Index.count)
    var maximumConcurrentLoads = 0
    var writeError: Error?
    var shouldFailLoads = false
    var duplicateProfiles = false
    var pushRows: [PushRow] = []
    var responseRows: [PushResponseRow] = []
    var presenceRows: [CurrentPresenceRow] = []
    /// Overridable so push-invitee tests can supply their own group rosters;
    /// defaults to the fixture the pre-existing store tests expect.
    var membershipRows = [GroupMembershipRow(
        id: "membership", person_id: "self", group_id: "group", role: "owner",
        membership_status: "active", joined_at: "2026-07-14T00:00:00Z"
    )]
    private var activeLoads = 0

    func loadProfiles() async throws -> [ProfileRow] {
        try await load(index: Index.profiles)
        var rows: [ProfileRow] = [.fixture(id: "friend", name: "Friend"), .fixture(id: "self", name: "Self")]
        if duplicateProfiles { rows.append(.fixture(id: "friend", name: "Duplicate")) }
        return rows
    }

    func loadGroups() async throws -> [GroupRow] {
        try await load(index: Index.groups)
        return [GroupRow(id: "group", name: "Crew", image_asset_path: nil)]
    }

    func loadMemberships() async throws -> [GroupMembershipRow] {
        try await load(index: Index.memberships)
        return membershipRows
    }

    func loadPolicies() async throws -> [SharingPolicyRow] {
        try await load(index: Index.policies)
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

    /// Mirrors dual-write RPC: updates last raw availability for presence spies.
    var lastAvailabilityRawValue: String?
    var setAvailabilityChoiceCallCount = 0

    func updateAvailability(userID: String, rawValue: String) async throws -> ProfileRow {
        setAvailabilityChoiceCallCount += 1
        lastAvailabilityRawValue = rawValue
        if let writeError { throw writeError }
        // Also mirror presence row availability when tests seeded one (RPC parity).
        if let index = presenceRows.firstIndex(where: {
            $0.user_id.caseInsensitiveCompare(userID) == .orderedSame
        }) {
            let old = presenceRows[index]
            presenceRows[index] = CurrentPresenceRow(
                user_id: old.user_id,
                availability: rawValue,
                is_published: old.is_published,
                activity_name: old.activity_name,
                activity_symbol: old.activity_symbol,
                place_id: old.place_id,
                status_note: old.status_note,
                latitude: old.latitude,
                longitude: old.longitude,
                vague_latitude: old.vague_latitude,
                vague_longitude: old.vague_longitude,
                confidence: old.confidence,
                observed_at: old.observed_at,
                updated_at: old.updated_at,
                expires_at: old.expires_at,
                source: old.source
            )
        }
        return .fixture(id: userID, name: "Self", availability: rawValue)
    }

    func updateImagePath(userID: String, imageAssetPath: String?) async throws -> ProfileRow {
        if let writeError { throw writeError }
        return .fixture(id: userID, name: "Self", imagePath: imageAssetPath)
    }

    private func load(index: Int) async throws {
        if shouldFailLoads { throw TestFailure.expected }
        loadCounts[index] += 1
        activeLoads += 1
        maximumConcurrentLoads = max(maximumConcurrentLoads, activeLoads)
        try await Task.sleep(nanoseconds: 20_000_000)
        activeLoads -= 1
    }

    // MARK: - Pushes (stateful, so create/update/cancel/respond behavior can
    // be exercised end-to-end via `SupabasePushRepository` in other tests).

    func loadPushes() async throws -> [PushRow] {
        try await load(index: Index.pushes)
        return pushRows
    }

    func loadResponses() async throws -> [PushResponseRow] {
        try await load(index: Index.responses)
        return responseRows
    }

    func loadPresence() async throws -> [CurrentPresenceRow] {
        try await load(index: Index.presence)
        return presenceRows
    }

    /// Stateful presence upserts for Issue #75 write-path tests.
    var upsertPresenceCallCount = 0
    var unpublishPresenceCallCount = 0
    var lastUpsertPresencePayload: CurrentPresenceUpsertPayload?
    /// Authenticated user the unpublish RPC would target (tests default to `self`).
    var presenceOwnerUserID = "self"
    /// When true, the next presence write throws `writeError` (if set) or `TestFailure.expected`.
    var failNextPresenceWrite = false

    func upsertCurrentPresence(_ payload: CurrentPresenceUpsertPayload) async throws -> CurrentPresenceRow {
        upsertPresenceCallCount += 1
        lastUpsertPresencePayload = payload
        if failNextPresenceWrite {
            failNextPresenceWrite = false
            if let writeError { throw writeError }
            throw TestFailure.expected
        }
        if let writeError { throw writeError }
        let row = CurrentPresenceRow(
            user_id: payload.user_id,
            availability: payload.availability,
            is_published: payload.is_published,
            activity_name: payload.activity_name,
            activity_symbol: payload.activity_symbol,
            place_id: payload.place_id,
            status_note: payload.status_note,
            latitude: payload.latitude,
            longitude: payload.longitude,
            vague_latitude: payload.vague_latitude,
            vague_longitude: payload.vague_longitude,
            confidence: payload.confidence,
            observed_at: payload.observed_at,
            updated_at: payload.updated_at,
            expires_at: payload.expires_at,
            source: payload.source
        )
        if let index = presenceRows.firstIndex(where: {
            $0.user_id.caseInsensitiveCompare(payload.user_id) == .orderedSame
        }) {
            presenceRows[index] = row
        } else {
            presenceRows.append(row)
        }
        return row
    }

    func unpublishCurrentPresence() async throws {
        unpublishPresenceCallCount += 1
        if failNextPresenceWrite {
            failNextPresenceWrite = false
            if let writeError { throw writeError }
            throw TestFailure.expected
        }
        if let writeError { throw writeError }
        let now = "2030-01-01T12:45:00Z"
        let owner = presenceOwnerUserID
        presenceRows = presenceRows.map { row in
            guard row.user_id.caseInsensitiveCompare(owner) == .orderedSame else { return row }
            return CurrentPresenceRow(
                user_id: row.user_id,
                availability: row.availability,
                is_published: false,
                activity_name: row.activity_name,
                activity_symbol: row.activity_symbol,
                place_id: row.place_id,
                status_note: row.status_note,
                latitude: nil,
                longitude: nil,
                vague_latitude: nil,
                vague_longitude: nil,
                confidence: row.confidence,
                observed_at: row.observed_at,
                updated_at: now,
                expires_at: now,
                source: row.source
            )
        }
    }

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

    func cancelFriendRequest(id: String) async throws {
        if let writeError { throw writeError }
        guard let index = friendshipRows.firstIndex(where: {
            $0.id == id && $0.isPending && $0.isRequester("self")
        }) else {
            throw SupabaseRepositoryError.notFound
        }
        friendshipRows.remove(at: index)
    }

    var blockedRows: [SearchProfileRow] = []

    func removeFriend(targetUserID: String) async throws {
        if let writeError { throw writeError }
        friendshipRows.removeAll {
            $0.involves("self") && $0.involves(targetUserID)
        }
    }

    func blockUser(targetUserID: String) async throws {
        if let writeError { throw writeError }
        friendshipRows.removeAll {
            $0.involves("self") && $0.involves(targetUserID)
        }
        if !blockedRows.contains(where: { $0.id.caseInsensitiveCompare(targetUserID) == .orderedSame }) {
            blockedRows.append(SearchProfileRow(
                id: targetUserID,
                first_name: targetUserID.capitalized,
                handle: targetUserID,
                image_asset_path: nil
            ))
        }
    }

    func unblockUser(targetUserID: String) async throws {
        if let writeError { throw writeError }
        blockedRows.removeAll {
            $0.id.caseInsensitiveCompare(targetUserID) == .orderedSame
        }
    }

    func listBlockedUsers() async throws -> [SearchProfileRow] {
        if let writeError { throw writeError }
        return blockedRows
    }

    func loadProfile(id: String) async throws -> ProfileRow {
        .fixture(id: id, name: id.capitalized)
    }

    // MARK: - Group invites

    var createdGroupRows: [GroupRow] = []
    var groupInviteRows: [GroupInviteRow] = []

    func createGroup(name: String, imageAssetPath: String?, inviteeIDs: [String]) async throws -> GroupRow {
        if let writeError { throw writeError }
        let row = GroupRow(id: "group-\(createdGroupRows.count + 1)", name: name, image_asset_path: imageAssetPath)
        createdGroupRows.append(row)
        return row
    }

    func incomingGroupInvites() async throws -> [GroupInviteRow] { groupInviteRows }

    func resolveGroupInvite(membershipID: String, accept: Bool) async throws -> GroupMembershipRow {
        if let writeError { throw writeError }
        guard let index = membershipRows.firstIndex(where: { $0.id == membershipID }) else {
            throw SupabaseRepositoryError.notFound
        }
        let existing = membershipRows[index]
        if accept {
            let updated = GroupMembershipRow(
                id: existing.id, person_id: existing.person_id, group_id: existing.group_id,
                role: existing.role, membership_status: "active", joined_at: existing.joined_at
            )
            membershipRows[index] = updated
            return updated
        }
        membershipRows.remove(at: index)
        return existing
    }

    // MARK: - Group lifecycle (0015)

    func renameGroup(groupID: String, name: String) async throws -> GroupRow {
        if let writeError { throw writeError }
        return GroupRow(id: groupID, name: name, image_asset_path: nil)
    }

    func setGroupImage(groupID: String, imagePath: String?) async throws -> GroupRow {
        if let writeError { throw writeError }
        return GroupRow(id: groupID, name: "Crew", image_asset_path: imagePath)
    }

    func inviteToGroup(groupID: String, inviteeIDs: [String]) async throws {
        if let writeError { throw writeError }
    }

    func cancelGroupInvite(membershipID: String) async throws {
        if let writeError { throw writeError }
    }

    func removeGroupMember(groupID: String, personID: String) async throws {
        if let writeError { throw writeError }
    }

    func leaveGroup(groupID: String) async throws {
        if let writeError { throw writeError }
    }

    func transferGroupOwnership(groupID: String, newOwnerID: String) async throws {
        if let writeError { throw writeError }
    }

    func deleteGroup(groupID: String) async throws {
        if let writeError { throw writeError }
    }
}

private enum TestFailure: Error { case expected }

@MainActor
private extension LiveDataStoreTests {
    static func samplePushRow(id: String, creator: String) -> PushRow {
        // Far-future expiry so time-derived `activePlans()` still includes the
        // fixture regardless of when the suite runs.
        PushRow(
            id: id, title: "Hang", group_id: nil, creator_id: creator,
            created_at: "2030-01-01T00:00:00Z", updated_at: "2030-01-01T00:00:00Z",
            starts_at: "2030-01-02T18:00:00Z", has_explicit_time: true,
            is_approximate_time: false, expires_at: "2030-01-03T00:00:00Z",
            cancelled_at: nil, place_id: nil, place_is_suggested: false,
            state: "collecting", audience: "invitees_only", note: nil, location_text: nil
        )
    }

    static func sampleResponseRow(pushID: String, personID: String) -> PushResponseRow {
        PushResponseRow(
            id: "\(pushID)-\(personID)", push_id: pushID, person_id: personID,
            response: "in", responded_at: "2026-07-14T00:00:00Z", ready_state: "unknown"
        )
    }
}

private extension ProfileRow {
    static func fixture(
        id: String,
        name: String,
        handle: String = "@test",
        availability: String = "free_now",
        imagePath: String? = nil
    ) -> ProfileRow {
        ProfileRow(
            id: id, first_name: name, handle: handle, image_asset_path: imagePath,
            availability_choice: availability, visibility_note: "Visible",
            settings_activity_visibility: nil, settings_map_preferences: nil,
            settings_close_friends: nil
        )
    }
}

extension CurrentPresenceRow {
    /// Test fixture for live presence reads (Issue #73).
    static func fixture(
        userID: String,
        availability: String = "free_now",
        isPublished: Bool = true,
        activityName: String = "",
        activitySymbol: String = "",
        statusNote: String? = nil,
        lat: Double? = 37.7749,
        lng: Double? = -122.4194,
        vagueLat: Double? = nil,
        vagueLng: Double? = nil,
        confidence: String = "medium",
        observedAt: String = "2030-01-01T12:00:00Z",
        updatedAt: String = "2030-01-01T12:00:00Z",
        expiresAt: String? = "2030-01-01T13:00:00Z",
        source: String = "location"
    ) -> CurrentPresenceRow {
        CurrentPresenceRow(
            user_id: userID,
            availability: availability,
            is_published: isPublished,
            activity_name: activityName,
            activity_symbol: activitySymbol,
            place_id: nil,
            status_note: statusNote,
            latitude: lat,
            longitude: lng,
            vague_latitude: vagueLat,
            vague_longitude: vagueLng,
            confidence: confidence,
            observed_at: observedAt,
            updated_at: updatedAt,
            expires_at: expiresAt,
            source: source
        )
    }
}
