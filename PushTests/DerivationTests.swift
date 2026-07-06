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
}
