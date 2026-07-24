//
//  LivePresenceReadTests.swift
//  PushTests
//
//  Issue #73 / architecture PR5 — live current_presence reads, synthetic
//  Place mapping, store warm/refresh, and map builder integration.
//  No device GPS, Core Location, or network required.
//

import XCTest
@testable import Push

final class LivePresenceReadTests: XCTestCase {

    /// Midpoint between fixture `updated_at` (12:00Z) and `expires_at` (13:00Z).
    private let now = Date(timeIntervalSince1970: 1_893_501_000) // 2030-01-01T12:30:00Z
    private let friendID = "friend-uuid"
    private let selfID = "self-uuid"

    // MARK: - Row → PresenceStatus

    func testValidRowMapsIntoPresenceStatus() throws {
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            availability: "maybe_down",
            activityName: "Walk",
            activitySymbol: "figure.walk",
            statusNote: "Out for air",
            lat: 37.77,
            lng: -122.42,
            confidence: "high",
            source: "location"
        )
        let status = try XCTUnwrap(row.presenceStatus())

        XCTAssertEqual(status.personID, friendID)
        XCTAssertEqual(status.availability, .maybeDown)
        XCTAssertTrue(status.isPublished)
        XCTAssertEqual(status.activity.name, "Walk")
        XCTAssertEqual(status.activity.symbolName, "figure.walk")
        XCTAssertEqual(status.statusNote, "Out for air")
        XCTAssertEqual(status.confidence, .high)
        XCTAssertEqual(status.source, .location)
        XCTAssertEqual(status.placeID, CurrentPresenceRow.syntheticPlaceID(for: friendID))
        XCTAssertEqual(status.id, "presence-\(friendID)")
    }

    func testLegacyGhostAvailabilityIsEffectivelyUnpublished() throws {
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            availability: "ghost",
            isPublished: true
        )
        let status = try XCTUnwrap(row.presenceStatus())
        XCTAssertEqual(status.availability, .ghost)
        XCTAssertFalse(status.isEffectivelyPublished)
    }

    func testManualOverrideSourceMaps() throws {
        let row = CurrentPresenceRow.fixture(userID: friendID, source: "manual_override")
        XCTAssertEqual(try XCTUnwrap(row.presenceStatus()).source, .manualOverride)
    }

    func testMalformedTimestampsRejectRow() {
        let bad = CurrentPresenceRow.fixture(
            userID: friendID,
            observedAt: "not-a-date",
            updatedAt: "2030-01-01T12:00:00Z"
        )
        XCTAssertNil(bad.presenceStatus())
    }

    func testPartialExactCoordinatesRejectRow() {
        // Defensive: DB pair constraint should prevent this, but mapping must not crash.
        let partial = CurrentPresenceRow(
            user_id: friendID,
            availability: "free_now",
            is_published: true,
            activity_name: "",
            activity_symbol: "",
            place_id: nil,
            status_note: nil,
            latitude: 37.77,
            longitude: nil,
            vague_latitude: nil,
            vague_longitude: nil,
            confidence: "medium",
            observed_at: "2030-01-01T12:00:00Z",
            updated_at: "2030-01-01T12:00:00Z",
            expires_at: "2030-01-01T13:00:00Z",
            source: "location"
        )
        XCTAssertNil(partial.presenceStatus())
        XCTAssertNil(partial.syntheticPlace())
    }

    func testOutOfRangeCoordinatesRejectRow() {
        let bad = CurrentPresenceRow.fixture(userID: friendID, lat: 91, lng: -122)
        XCTAssertNil(bad.presenceStatus())
    }

    // MARK: - Filtering

    func testHardExpiredRowsExcluded() {
        let expired = CurrentPresenceRow.fixture(
            userID: friendID,
            updatedAt: "2029-12-31T12:00:00Z",
            expiresAt: "2029-12-31T13:00:00Z"
        )
        let statuses = CurrentPresenceRow.friendVisibleStatuses(
            from: [expired], viewerID: selfID, now: now
        )
        XCTAssertTrue(statuses.isEmpty)
    }

    func testUnpublishedNonSelfRowsExcluded() {
        let unpublished = CurrentPresenceRow.fixture(
            userID: friendID,
            isPublished: false
        )
        let statuses = CurrentPresenceRow.friendVisibleStatuses(
            from: [unpublished], viewerID: selfID, now: now
        )
        XCTAssertTrue(statuses.isEmpty)
    }

    func testUnpublishedSelfRowPreserved() {
        let unpublished = CurrentPresenceRow.fixture(
            userID: selfID,
            isPublished: false,
            lat: nil,
            lng: nil,
            expiresAt: nil
        )
        let statuses = CurrentPresenceRow.friendVisibleStatuses(
            from: [unpublished], viewerID: selfID, now: now
        )
        XCTAssertEqual(statuses.map(\.personID), [selfID])
        XCTAssertFalse(statuses[0].isEffectivelyPublished)
    }

    func testLegacyGhostNonSelfFailsClosed() {
        let ghost = CurrentPresenceRow.fixture(
            userID: friendID,
            availability: "ghost",
            isPublished: true
        )
        let statuses = CurrentPresenceRow.friendVisibleStatuses(
            from: [ghost], viewerID: selfID, now: now
        )
        XCTAssertTrue(statuses.isEmpty)
    }

    func testSoftStaleRemainsVisible() {
        let softStaleUpdated = now.addingTimeInterval(-(PresenceFreshness.softStale + 30))
        let expires = now.addingTimeInterval(PresenceFreshness.hardExpire)
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            updatedAt: iso(softStaleUpdated),
            expiresAt: iso(expires)
        )
        let statuses = CurrentPresenceRow.friendVisibleStatuses(
            from: [row], viewerID: selfID, now: now
        )
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses[0].freshnessState(at: now), .softStale)
    }

    // MARK: - Synthetic Place

    func testSyntheticPlaceStableIDAndExactCoordinates() throws {
        let row = CurrentPresenceRow.fixture(
            userID: "AbC-DEF",
            lat: 37.7749,
            lng: -122.4194,
            vagueLat: 37.77,
            vagueLng: -122.42
        )
        let place = try XCTUnwrap(row.syntheticPlace())
        XCTAssertEqual(place.id, "presence-abc-def")
        XCTAssertEqual(place.latitude, 37.7749, accuracy: 0.00001)
        XCTAssertEqual(place.longitude, -122.4194, accuracy: 0.00001)
        XCTAssertEqual(place.vagueLatitude, 37.77)
        XCTAssertEqual(place.vagueLongitude, -122.42)
        XCTAssertEqual(place.vagueLabel, CurrentPresenceRow.nearbyLabel)
        XCTAssertEqual(place.address, CurrentPresenceRow.sharedLocationAddress)
        XCTAssertEqual(place.name, CurrentPresenceRow.nearbyLabel)
    }

    func testSyntheticPlaceUsesActivityNameWhenPresent() throws {
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            activityName: "Coffee",
            lat: 37.77,
            lng: -122.42
        )
        let place = try XCTUnwrap(row.syntheticPlace())
        XCTAssertEqual(place.name, "Coffee")
        XCTAssertEqual(place.shortName, "Coffee")
        XCTAssertEqual(place.vagueLabel, CurrentPresenceRow.nearbyLabel)
    }

    func testVagueCoordinatesFallbackWhenServerOmitsPair() throws {
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            lat: 37.7749,
            lng: -122.4194,
            vagueLat: nil,
            vagueLng: nil
        )
        let place = try XCTUnwrap(row.syntheticPlace())
        let q = CurrentPresenceRow.vagueCoordinateQuantumDegrees
        XCTAssertEqual(
            try XCTUnwrap(place.vagueLatitude),
            (37.7749 / q).rounded() * q,
            accuracy: 0.00001
        )
        XCTAssertEqual(
            try XCTUnwrap(place.vagueLongitude),
            (-122.4194 / q).rounded() * q,
            accuracy: 0.00001
        )
    }

    func testSyntheticPlacesOnlyForVisibleStatuses() {
        let friend = CurrentPresenceRow.fixture(userID: friendID, lat: 37.77, lng: -122.42)
        let ghost = CurrentPresenceRow.fixture(
            userID: "ghost-user", availability: "ghost", lat: 37.78, lng: -122.41
        )
        let expired = CurrentPresenceRow.fixture(
            userID: "expired-user",
            lat: 37.79,
            lng: -122.40,
            expiresAt: "2000-01-01T00:00:00Z"
        )
        let places = CurrentPresenceRow.syntheticPlaces(
            from: [friend, ghost, expired], viewerID: selfID, now: now
        )
        XCTAssertEqual(places.map(\.id), [CurrentPresenceRow.syntheticPlaceID(for: friendID)])
    }

    // MARK: - Live repositories

    @MainActor
    func testLiveRepositoryReturnsMappedPresenceNotSeed() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            .fixture(userID: "friend", activityName: "Gym", lat: 37.77, lng: -122.42)
        ]
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")

        let statuses = try await container.friends.presenceStatuses()
        let places = try await container.pushes.allPlaces()

        XCTAssertEqual(statuses.map(\.personID), ["friend"])
        XCTAssertEqual(statuses.first?.activity.name, "Gym")
        XCTAssertEqual(places.map(\.id), [CurrentPresenceRow.syntheticPlaceID(for: "friend")])
        // Must not invent seed-style place ids (crunch, cafe, etc.).
        XCTAssertFalse(places.contains { !$0.id.hasPrefix("presence-") })
    }

    @MainActor
    func testZeroLiveRowsPreserveEmptyPresenceAndPlaces() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = []
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")

        let statuses = try await container.friends.presenceStatuses()
        let places = try await container.pushes.allPlaces()
        XCTAssertTrue(statuses.isEmpty)
        XCTAssertTrue(places.isEmpty)
    }

    @MainActor
    func testLiveRepositoryFiltersExpiredAndUnpublished() async throws {
        let loader = LiveDataLoaderSpy()
        loader.presenceRows = [
            .fixture(userID: "friend", lat: 37.77, lng: -122.42),
            .fixture(userID: "hidden", isPublished: false, lat: 37.78, lng: -122.41),
            .fixture(
                userID: "stale",
                lat: 37.79,
                lng: -122.40,
                expiresAt: "2000-01-01T00:00:00Z"
            )
        ]
        let container = try await AppDataContainer.prepareLive(loader: loader, currentUserID: "self")
        let statuses = try await container.friends.presenceStatuses()
        XCTAssertEqual(statuses.map(\.personID), ["friend"])
    }

    // MARK: - Map builders + sharing policy

    func testFixtureLiveRowsProduceMapPucksThroughExistingBuilders() throws {
        let person = Person(id: friendID, firstName: "Friend", imageAssetPath: nil)
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            activityName: "Coffee",
            lat: 37.77,
            lng: -122.42
        )
        let status = try XCTUnwrap(row.presenceStatus())
        let place = try XCTUnwrap(row.syntheticPlace())
        let policy = SharingPolicy(
            id: "p1",
            ownerPersonID: friendID,
            audienceType: .globalDefault,
            audienceID: nil,
            locationVisibility: .exact,
            activityVisibility: .full,
            availabilityVisibility: .full,
            expiresAt: nil
        )
        let presence = try XCTUnwrap(
            VisiblePresenceBuilder.visiblePresence(
                of: status,
                owner: person,
                viewerID: selfID,
                sharedGroupIDs: [],
                policies: [policy],
                placesByID: [place.id: place],
                now: now
            )
        )
        let pucks = MapContentBuilder.pucks(
            presences: [presence],
            groups: [],
            memberships: [],
            now: now
        )
        XCTAssertEqual(pucks.count, 1)
        XCTAssertEqual(pucks[0].people.map(\.id), [friendID])
        XCTAssertEqual(pucks[0].coordinate.latitude, 37.77, accuracy: 0.0001)
        XCTAssertEqual(pucks[0].coordinate.longitude, -122.42, accuracy: 0.0001)
    }

    func testZeroRowsProduceNoMapPucks() {
        let pucks = MapContentBuilder.pucks(
            presences: [], groups: [], memberships: [], now: now
        )
        XCTAssertTrue(pucks.isEmpty)
    }

    func testSharingPolicyExactVagueHiddenWithSyntheticPlace() throws {
        let person = Person(id: friendID, firstName: "Friend", imageAssetPath: nil)
        let row = CurrentPresenceRow.fixture(
            userID: friendID,
            lat: 37.7749,
            lng: -122.4194,
            vagueLat: 37.76,
            vagueLng: -122.41
        )
        let status = try XCTUnwrap(row.presenceStatus())
        let place = try XCTUnwrap(row.syntheticPlace())
        let placesByID = [place.id: place]

        func presence(location: SharingPolicy.LocationVisibility) -> VisiblePresence? {
            let policy = SharingPolicy(
                id: "pol-\(location.rawValue)",
                ownerPersonID: friendID,
                audienceType: .globalDefault,
                audienceID: nil,
                locationVisibility: location,
                activityVisibility: .full,
                availabilityVisibility: .full,
                expiresAt: nil
            )
            return VisiblePresenceBuilder.visiblePresence(
                of: status,
                owner: person,
                viewerID: selfID,
                sharedGroupIDs: [],
                policies: [policy],
                placesByID: placesByID,
                now: now
            )
        }

        let exact = try XCTUnwrap(presence(location: .exact))
        XCTAssertEqual(exact.placeInfo?.isVague, false)
        XCTAssertEqual(try XCTUnwrap(exact.placeInfo).place.latitude, 37.7749, accuracy: 0.00001)

        let vague = try XCTUnwrap(presence(location: .vague))
        XCTAssertEqual(vague.placeInfo?.isVague, true)
        XCTAssertEqual(try XCTUnwrap(vague.placeInfo).place.vagueLatitude, 37.76)
        XCTAssertEqual(vague.placeInfo?.displayName, CurrentPresenceRow.nearbyLabel)

        let hidden = try XCTUnwrap(presence(location: .hidden))
        XCTAssertNil(hidden.placeInfo)
    }

    func testVisiblePresenceBuilderDropsUnpublishedNonSelf() {
        let person = Person(id: friendID, firstName: "Friend", imageAssetPath: nil)
        let status = PresenceStatus(
            id: "p",
            personID: friendID,
            availability: .busy,
            activity: PresenceActivity(name: "", symbolName: ""),
            placeID: CurrentPresenceRow.syntheticPlaceID(for: friendID),
            statusNote: nil,
            confidence: .medium,
            observedAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(3600),
            source: .location,
            isPublished: false
        )
        let place = Place(
            id: CurrentPresenceRow.syntheticPlaceID(for: friendID),
            name: "Nearby",
            shortName: "Nearby",
            address: "",
            vagueLabel: "Nearby",
            latitude: 37.77,
            longitude: -122.42
        )
        let policy = SharingPolicy(
            id: "p1",
            ownerPersonID: friendID,
            audienceType: .globalDefault,
            audienceID: nil,
            locationVisibility: .exact,
            activityVisibility: .full,
            availabilityVisibility: .full,
            expiresAt: nil
        )
        XCTAssertNil(
            VisiblePresenceBuilder.visiblePresence(
                of: status,
                owner: person,
                viewerID: selfID,
                sharedGroupIDs: [],
                policies: [policy],
                placesByID: [place.id: place],
                now: now
            )
        )
    }

    // MARK: - JSON decode

    func testCurrentPresenceRowDecodesPostgRESTShape() throws {
        let json = """
        {"user_id":"11111111-1111-1111-1111-111111111111","availability":"free_now",
         "is_published":true,"activity_name":"","activity_symbol":"","place_id":null,
         "status_note":null,"latitude":37.77,"longitude":-122.42,
         "vague_latitude":null,"vague_longitude":null,"confidence":"medium",
         "observed_at":"2026-07-23T12:00:00.123456+00:00",
         "updated_at":"2026-07-23T12:00:00.123456+00:00",
         "expires_at":"2026-07-23T13:00:00+00:00","source":"location"}
        """.data(using: .utf8)!
        let row = try JSONDecoder().decode(CurrentPresenceRow.self, from: json)
        let status = try XCTUnwrap(row.presenceStatus())
        XCTAssertEqual(status.personID, "11111111-1111-1111-1111-111111111111")
        XCTAssertNotEqual(status.observedAt, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(status.placeID, "presence-11111111-1111-1111-1111-111111111111")
    }

    // MARK: - Helpers

    private func iso(_ date: Date) -> String {
        PushDateFormatting.string(date)
    }
}
