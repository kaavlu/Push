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

@MainActor
private final class LiveDataLoaderSpy: LiveDataLoading {
    var loadCounts = [0, 0, 0, 0]
    var maximumConcurrentLoads = 0
    var writeError: Error?
    var duplicateProfiles = false
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
        return [GroupMembershipRow(
            id: "membership", person_id: "self", group_id: "group", role: "owner",
            membership_status: "active", joined_at: "2026-07-14T00:00:00Z"
        )]
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
