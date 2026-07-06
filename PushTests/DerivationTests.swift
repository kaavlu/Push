//
//  DerivationTests.swift
//  PushTests
//
//  Covers the derivation pipeline: sharing-policy resolution → visible
//  presence → screen content builders.
//

import XCTest
@testable import Push

final class DerivationTests: XCTestCase {

    // MARK: - Fixtures

    private let owner = Person(id: "owner", firstName: "owner", imageAssetPath: nil)
    private let place = Place(
        id: "cafe", name: "Cafe Reveille", shortName: "Reveille",
        address: "610 Long Bridge St", vagueLabel: "Mission Bay",
        latitude: 37.77, longitude: -122.39
    )
    private let now = Date()

    private func makeStatus(note: String? = "Grabbing coffee") -> PresenceStatus {
        PresenceStatus(
            id: "status-owner",
            personID: "owner",
            availability: .freeNow,
            activity: PresenceActivity(name: "Coffee", symbolName: "cup.and.saucer.fill"),
            placeID: "cafe",
            statusNote: note,
            confidence: .high,
            observedAt: now,
            updatedAt: now,
            expiresAt: nil,
            source: .seed
        )
    }

    private func makePolicy(
        audienceType: SharingPolicy.AudienceType = .globalDefault,
        audienceID: String? = nil,
        location: SharingPolicy.LocationVisibility = .exact,
        activity: SharingPolicy.DetailVisibility = .full,
        availability: SharingPolicy.AvailabilityVisibility = .full,
        expiresAt: Date? = nil
    ) -> SharingPolicy {
        SharingPolicy(
            id: "policy-\(audienceType.rawValue)-\(audienceID ?? "none")",
            ownerPersonID: "owner",
            audienceType: audienceType,
            audienceID: audienceID,
            locationVisibility: location,
            activityVisibility: activity,
            availabilityVisibility: availability,
            expiresAt: expiresAt
        )
    }

    private func visible(
        policies: [SharingPolicy],
        viewerID: String = "viewer",
        sharedGroupIDs: Set<String> = []
    ) -> VisiblePresence? {
        VisiblePresenceBuilder.visiblePresence(
            of: makeStatus(),
            owner: owner,
            viewerID: viewerID,
            sharedGroupIDs: sharedGroupIDs,
            policies: policies,
            placesByID: ["cafe": place],
            now: now
        )
    }

    // MARK: - Visible presence

    func testFullDefaultPolicyPassesEverythingThrough() throws {
        let presence = try XCTUnwrap(visible(policies: [makePolicy()]))
        XCTAssertEqual(presence.availability, .freeNow)
        XCTAssertEqual(presence.activity?.name, "Coffee")
        XCTAssertEqual(presence.statusNote, "Grabbing coffee")
        XCTAssertEqual(presence.placeInfo?.isVague, false)
        XCTAssertEqual(presence.placeInfo?.displayName, "Reveille")
    }

    func testHiddenAvailabilityRemovesPersonFromBoard() {
        XCTAssertNil(visible(policies: [makePolicy(availability: .hidden)]))
    }

    func testNoPolicySharesNothing() {
        XCTAssertNil(visible(policies: []))
    }

    func testVagueLocationUsesNeighborhoodLabel() throws {
        let presence = try XCTUnwrap(visible(policies: [makePolicy(location: .vague)]))
        XCTAssertEqual(presence.placeInfo?.isVague, true)
        XCTAssertEqual(presence.placeInfo?.displayName, "Mission Bay")
    }

    func testHiddenLocationDropsPlace() throws {
        let presence = try XCTUnwrap(visible(policies: [makePolicy(location: .hidden)]))
        XCTAssertNil(presence.placeInfo)
    }

    func testVagueActivityDropsStatusNote() throws {
        let presence = try XCTUnwrap(visible(policies: [makePolicy(activity: .vague)]))
        XCTAssertEqual(presence.activity?.name, "Coffee")
        XCTAssertNil(presence.statusNote)
    }

    func testHiddenActivityDropsActivityAndNote() throws {
        let presence = try XCTUnwrap(visible(policies: [makePolicy(activity: .hidden)]))
        XCTAssertNil(presence.activity)
        XCTAssertNil(presence.statusNote)
    }

    func testFriendPolicyBeatsGlobalDefault() throws {
        let policies = [
            makePolicy(location: .exact),
            makePolicy(audienceType: .friend, audienceID: "viewer", location: .vague)
        ]
        let presence = try XCTUnwrap(visible(policies: policies))
        XCTAssertEqual(presence.placeInfo?.isVague, true)
    }

    func testExpiredFriendPolicyFallsBackToDefault() throws {
        let policies = [
            makePolicy(location: .exact),
            makePolicy(
                audienceType: .friend, audienceID: "viewer", location: .vague,
                expiresAt: now.addingTimeInterval(-60)
            )
        ]
        let presence = try XCTUnwrap(visible(policies: policies))
        XCTAssertEqual(presence.placeInfo?.isVague, false)
    }

    func testGroupPolicyAppliesToSharedGroups() throws {
        let policies = [
            makePolicy(location: .exact),
            makePolicy(audienceType: .group, audienceID: "climbing", location: .vague)
        ]
        let presence = try XCTUnwrap(
            visible(policies: policies, sharedGroupIDs: ["climbing"])
        )
        XCTAssertEqual(presence.placeInfo?.isVague, true)
    }

    func testSelfAlwaysSeesEverything() throws {
        let presence = try XCTUnwrap(visible(policies: [], viewerID: "owner"))
        XCTAssertEqual(presence.isCurrentUser, true)
        XCTAssertEqual(presence.placeInfo?.isVague, false)
        XCTAssertEqual(presence.statusNote, "Grabbing coffee")
    }

    // MARK: - Map pucks from seed

    private func seedPucks(now: Date = Date()) -> [MapPuckData] {
        let seed = SeedData.standard(now: now)
        let placesByID = Dictionary(uniqueKeysWithValues: seed.places.map { ($0.id, $0) })
        let peopleByID = Dictionary(uniqueKeysWithValues: seed.people.map { ($0.id, $0) })
        let viewerID = seed.currentUserID
        let groupIDsByPerson: [String: Set<String>] = seed.memberships.reduce(into: [:]) {
            $0[$1.personID, default: []].insert($1.groupID)
        }
        let viewerGroups = groupIDsByPerson[viewerID] ?? []
        let presences = seed.statuses.compactMap { status -> VisiblePresence? in
            guard let owner = peopleByID[status.personID] else { return nil }
            let shared = viewerGroups.intersection(groupIDsByPerson[owner.id] ?? [])
            return VisiblePresenceBuilder.visiblePresence(
                of: status, owner: owner, viewerID: viewerID, sharedGroupIDs: shared,
                policies: seed.policies, placesByID: placesByID, now: now
            )
        }
        return MapContentBuilder.pucks(
            presences: presences, groups: seed.groups, memberships: seed.memberships, now: now
        )
    }

    func testMapBuilderReproducesCurrentPuckMix() {
        let pucks = seedPucks()
        XCTAssertEqual(pucks.count, 5)
        XCTAssertEqual(pucks.filter { $0.kind == .individual }.count, 2)
        XCTAssertEqual(pucks.filter { $0.kind == .hangout }.count, 1)
        XCTAssertEqual(pucks.filter { $0.kind == .cluster }.count, 1)
        XCTAssertEqual(pucks.filter { $0.kind == .friendGroup }.count, 1)
    }

    func testClusterIsRohanRyanPranayAfterRamFix() throws {
        let cluster = try XCTUnwrap(seedPucks().first { $0.kind == .cluster })
        XCTAssertEqual(cluster.id, "puck-dolores-lawn")
        XCTAssertEqual(cluster.people.map(\.name), ["Rohan", "Ryan", "Pranay"])
    }

    func testFriendGroupPuckMatchesExecWithGroupAvatarFirst() throws {
        let exec = try XCTUnwrap(seedPucks().first { $0.kind == .friendGroup })
        XCTAssertEqual(exec.id, "puck-crunch")
        XCTAssertEqual(exec.people.first?.id, "group-exec")
        XCTAssertEqual(exec.people.first?.name, "Exec")
        XCTAssertEqual(exec.people.last?.isCurrentUser, true)
        XCTAssertTrue(exec.includesCurrentUser)
    }

    func testPuckVenueTextsMatchToday() {
        let texts = Set(seedPucks().map(\.venueStatusText))
        XCTAssertEqual(texts, [
            "At Blue Bottle",
            "Near Dolores",
            "At Souvla",
            "Group forming near Dolores",
            "At Crunch"
        ])
    }

    func testMultiPersonPucksDeriveJoinable() {
        let multi = seedPucks().filter { $0.people.count > 1 }
        XCTAssertFalse(multi.isEmpty)
        XCTAssertTrue(multi.allSatisfy { $0.availability == .joinable })
        for puck in multi {
            XCTAssertTrue(puck.people.allSatisfy { $0.availability == .joinable }, puck.id)
        }
    }

    func testGroupTagsFilterLikeToday() {
        let pucks = seedPucks()
        XCTAssertEqual(pucks.filter { $0.groupIDs.contains("india") }.count, 3)
        XCTAssertEqual(pucks.filter { $0.groupIDs.contains("michigan") }.count, 1)
        XCTAssertEqual(pucks.filter { $0.groupIDs.contains("exec") }.count, 1)
        XCTAssertTrue(pucks.allSatisfy { !$0.groupIDs.isEmpty })
    }

    func testWithWhomDerivesFromCoLocation() throws {
        let souvla = try XCTUnwrap(seedPucks().first { $0.id == "puck-souvla" })
        let viplove = try XCTUnwrap(souvla.people.first { $0.id == "viplove" })
        XCTAssertEqual(viplove.withWhom, ["Ishan"])
        let nitin = try XCTUnwrap(seedPucks().first { $0.id == "puck-dolores-park" }?.people.first)
        XCTAssertNil(nitin.withWhom)
    }

    func testMemberPuckFieldsDeriveFromPlaceAndStatus() throws {
        let bluBottle = try XCTUnwrap(seedPucks().first { $0.id == "puck-blue-bottle" })
        let chitty = try XCTUnwrap(bluBottle.people.first)
        XCTAssertEqual(chitty.id, "chitty")
        XCTAssertEqual(chitty.activityDisplayText, "Blue Bottle")
        XCTAssertEqual(chitty.venueStatusText, "At Blue Bottle")
        XCTAssertEqual(chitty.lastUpdated, "3 min ago")
        XCTAssertEqual(chitty.locationLabel, "315 Linden St")
        XCTAssertEqual(chitty.placeName, "Blue Bottle")
    }
}
