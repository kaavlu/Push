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
        XCTAssertEqual(pucks.filter { $0.kind == .hangout }.count, 2)
        XCTAssertEqual(pucks.filter { $0.kind == .cluster }.count, 1)
        XCTAssertEqual(pucks.filter { $0.kind == .friendGroup }.count, 0)
    }

    func testClusterIsRohanRyanPranayAfterRamFix() throws {
        let cluster = try XCTUnwrap(seedPucks().first { $0.kind == .cluster })
        XCTAssertEqual(cluster.id, "puck-dolores-lawn")
        XCTAssertEqual(cluster.people.map(\.name), ["Rohan", "Ryan", "Pranay"])
    }

    func testCrunchPuckKeepsExecAfterRemovingCurrentUserFromExec() throws {
        let crunch = try XCTUnwrap(seedPucks().first { $0.id == "puck-crunch" })
        XCTAssertEqual(crunch.kind, .hangout)
        XCTAssertEqual(crunch.people.map(\.id), ["ram", "ohm"])
        XCTAssertEqual(crunch.groupIDs, ["exec", "michigan"])
        XCTAssertFalse(crunch.includesCurrentUser)
    }

    func testSoloCurrentUserRendersAsStandaloneLocationPin() {
        XCTAssertFalse(seedPucks().contains { $0.includesCurrentUser })
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
        XCTAssertEqual(pucks.filter { $0.groupIDs.contains("michigan") }.count, 2)
        XCTAssertEqual(pucks.filter { $0.groupIDs.contains("exec") }.count, 1)
        XCTAssertEqual(pucks.first { $0.id == "puck-crunch" }?.groupIDs, ["exec", "michigan"])
    }

    func testWithWhomDerivesFromCoLocation() throws {
        let souvla = try XCTUnwrap(seedPucks().first { $0.id == "puck-souvla" })
        let viplove = try XCTUnwrap(souvla.people.first { $0.id == "viplove" })
        XCTAssertEqual(viplove.withWhom, ["Ishan"])
        let nitin = try XCTUnwrap(seedPucks().first { $0.id == "puck-dolores-park" }?.people.first)
        XCTAssertNil(nitin.withWhom)
    }

    // MARK: - Group cards

    private func seedGroupCards(now: Date = Date()) -> [PushGroupData] {
        let seed = SeedData.standard(now: now)
        return GroupContentBuilder.groupCards(
            groups: seed.groups,
            memberships: seed.memberships,
            statuses: Dictionary(uniqueKeysWithValues: seed.statuses.map { ($0.personID, $0) }),
            plans: seed.plans,
            now: now
        )
    }

    func testGroupCardsDeriveCountsAndStats() {
        let cards = seedGroupCards()
        XCTAssertEqual(cards.map(\.name), ["India", "Exec", "Michigan"])
        XCTAssertEqual(cards.map(\.memberCount), [5, 2, 5])
        XCTAssertEqual(cards.map(\.activeNowCount), [2, 2, 5])
        XCTAssertEqual(cards.map(\.nearbyCount), [2, 0, 0])
        XCTAssertEqual(cards.map(\.planCount), [1, 2, 2])
    }

    func testGroupBadgesDeriveWithPlanLivePriority() {
        let cards = seedGroupCards()
        XCTAssertEqual(cards.map(\.status), [.activeNow, .activeNow, .planLive])
    }

    func testGroupMembersUseCanonicalAvailability() throws {
        let seed = SeedData.standard()
        let members = GroupContentBuilder.members(
            groupID: "india",
            memberships: seed.memberships,
            people: Dictionary(uniqueKeysWithValues: seed.people.map { ($0.id, $0) }),
            statuses: Dictionary(uniqueKeysWithValues: seed.statuses.map { ($0.personID, $0) })
        )
        XCTAssertEqual(members.map(\.name), ["Chitty", "Nitin", "Ishan", "Viplove", "Roh"])
        // Canonical value wins: the old groups table said nitin was joinable
        // while the map showed maybeDown — map wins.
        XCTAssertEqual(members.first { $0.id == "nitin" }?.availability, .maybeDown)
        XCTAssertEqual(members.first { $0.id == "roh" }?.availability, .unavailable)
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

    // MARK: - Push cards + calendar

    /// Wednesday noon: keeps "today"-relative timing labels deterministic.
    private var wednesdayNoon: Date {
        Calendar.current.date(
            from: DateComponents(year: 2026, month: 7, day: 8, hour: 12)
        ) ?? Date()
    }

    private func seedPlanData(now: Date) -> [PlanData] {
        let seed = SeedData.standard(now: now)
        return PlansContentBuilder.planData(
            plans: seed.plans,
            responses: seed.responses,
            groupsByID: Dictionary(uniqueKeysWithValues: seed.groups.map { ($0.id, $0) }),
            placesByID: Dictionary(uniqueKeysWithValues: seed.places.map { ($0.id, $0) }),
            peopleByID: Dictionary(uniqueKeysWithValues: seed.people.map { ($0.id, $0) }),
            currentUserID: seed.currentUserID,
            now: now
        )
    }

    func testPlanTimingLabelsMatchToday() {
        let plans = seedPlanData(now: wednesdayNoon)
        XCTAssertEqual(plans.map(\.timeSignal), [
            "8:00 PM", "~7:45 PM", "now", "Friday, 9:00 PM", "Saturday"
        ])
    }

    func testPlanSocialProofMatchesToday() {
        let plans = seedPlanData(now: wednesdayNoon)
        XCTAssertEqual(plans.map(\.socialProof), [
            "3 in · 2 maybe",
            "4 going",
            "Chitty is there · Ishan maybe",
            "2 in · 1 maybe",
            "Ram in · Ohm maybe"
        ])
    }

    func testPlanPillsOwnersAndParticipants() {
        let plans = seedPlanData(now: wednesdayNoon)
        XCTAssertEqual(plans.map(\.status), [.pending, .joined, .open, .pending, .waiting])
        XCTAssertEqual(plans.filter(\.isOwner).map(\.id), ["gym-later", "drinks-friday"])
        XCTAssertEqual(plans.first { $0.id == "gym-later" }?.participants.count, 4)
        XCTAssertEqual(plans.first { $0.id == "drinks-friday" }?.participants.count, 2)
        XCTAssertEqual(plans.map(\.group), ["Michigan", "Exec", "India", "Michigan", "Exec"])
        XCTAssertEqual(plans.map(\.locationHint), [
            "Suggested: North Park", "Crunch Fitness", "Blue Bottle",
            "Suggested: Little Italy", "Ram's place"
        ])
    }

    func testCalendarDerivesFromHangouts() {
        let seed = SeedData.standard(now: wednesdayNoon)
        let peopleByID = Dictionary(uniqueKeysWithValues: seed.people.map { ($0.id, $0) })
        let days = PlansContentBuilder.calendarDays(
            hangouts: seed.hangouts, peopleByID: peopleByID, month: wednesdayNoon
        )
        XCTAssertEqual(days.count, 31)
        XCTAssertEqual(days.reduce(0) { $0 + $1.pushCount }, 19)

        let day5 = days[4]
        XCTAssertEqual(day5.pushCount, 3)
        XCTAssertEqual(day5.hadPlan, true)
        XCTAssertEqual(day5.hangouts.count, 3)
        XCTAssertEqual(day5.hangouts.first?.activityNote, "Pre-dinner drinks")

        let day14 = days[13]
        XCTAssertEqual(day14.pushCount, 0)
        XCTAssertEqual(day14.almostHappened, true)
        XCTAssertEqual(day14.hangouts.count, 0)

        let day18 = days[17]
        XCTAssertEqual(day18.pushCount, 2)
        XCTAssertEqual(day18.hadPlan, false)
    }

    func testSeedImageAssetPathsMatchBundledAssets() {
        let seed = SeedData.standard()
        let expected = Set(
            seed.people.compactMap(\.imageAssetPath) + seed.groups.compactMap(\.imageAssetPath)
        )
        XCTAssertTrue(expected.contains("assets/friends/chitty.png"))
        XCTAssertTrue(expected.contains("assets/profile/manav.jpeg"))
        XCTAssertTrue(expected.contains("assets/groups/Exec/ram.png"))
        XCTAssertTrue(expected.allSatisfy { $0.hasPrefix("assets/") })
    }

    func test_planData_handlesNilGroupAndPlace_usesLocationText() {
        let now = Date()
        let plan = PushPlan(
            id: "p1", title: "Coffee run", groupID: nil, creatorID: "me",
            createdAt: now, updatedAt: now, startsAt: now,
            hasExplicitTime: true, isApproximateTime: false,
            expiresAt: now.addingTimeInterval(3600), cancelledAt: nil,
            placeID: nil, placeIsSuggested: false, state: .collecting,
            audience: .inviteesOnly, note: nil, locationText: "Blue Bottle, Hayes"
        )
        let cards = PlansContentBuilder.planData(
            plans: [plan], responses: [], groupsByID: [:], placesByID: [:],
            peopleByID: [:], currentUserID: "me", now: now
        )
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].locationHint, "Blue Bottle, Hayes")
        XCTAssertEqual(cards[0].group, "")
    }

    func testMostActiveGroupDerivesFromHangouts() {
        let seed = SeedData.standard(now: wednesdayNoon)
        let name = PlansContentBuilder.mostActiveGroup(
            hangouts: seed.hangouts,
            memberships: seed.memberships,
            groupsByID: Dictionary(uniqueKeysWithValues: seed.groups.map { ($0.id, $0) }),
            groupOrder: seed.groups.map(\.id)
        )
        XCTAssertEqual(name, "Michigan")
    }
}
