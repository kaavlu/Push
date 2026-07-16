//
//  MapPuckHitTestingTests.swift
//  PushTests
//

import CoreLocation
import XCTest
@testable import Push

final class MapPuckHitTestingTests: XCTestCase {

    private let layout = PushAdaptiveLayout.reference

    func testHitRadiusScalesWithVisualPuckSize() {
        let friend = MapPuckRenderModel.friend(samplePuck(id: "f", kind: .individual))
        let cluster = MapPuckRenderModel.smallGroup(samplePuck(id: "c", kind: .cluster))
        let friendGroup = MapPuckRenderModel.smallGroup(samplePuck(id: "g", kind: .friendGroup))

        let friendRadius = MapPuckHitTesting.hitRadius(for: friend, layout: layout)
        let clusterRadius = MapPuckHitTesting.hitRadius(for: cluster, layout: layout)
        let groupRadius = MapPuckHitTesting.hitRadius(for: friendGroup, layout: layout)

        XCTAssertLessThan(friendRadius, clusterRadius)
        XCTAssertLessThan(friendRadius, groupRadius)
        XCTAssertEqual(
            friendRadius,
            MapPuckAnnotationLayout.individualPuckSize(layout) / 2 + MapPuckHitTesting.hitPadding,
            accuracy: 0.001
        )
    }

    func testZPriorityOrdersLargerGroupsAboveFriends() {
        let regional = MapPuckRenderModel.regionalCluster(sampleRegional(id: "r", members: 8))
        let hangout = MapPuckRenderModel.smallGroup(samplePuck(id: "h", kind: .hangout))
        let friendGroup = MapPuckRenderModel.smallGroup(samplePuck(id: "g", kind: .friendGroup))
        let friend = MapPuckRenderModel.friend(samplePuck(id: "f", kind: .individual))
        let selfPuck = MapPuckRenderModel.selfPuck(
            SelfPuckData(
                id: "self",
                avatarPlaceholder: "MK",
                profileImageAssetName: nil,
                coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)
            )
        )

        XCTAssertGreaterThan(
            MapPuckHitTesting.zPriority(for: regional),
            MapPuckHitTesting.zPriority(for: hangout)
        )
        XCTAssertGreaterThan(
            MapPuckHitTesting.zPriority(for: hangout),
            MapPuckHitTesting.zPriority(for: friendGroup)
        )
        XCTAssertGreaterThan(
            MapPuckHitTesting.zPriority(for: friendGroup),
            MapPuckHitTesting.zPriority(for: friend)
        )
        XCTAssertGreaterThan(
            MapPuckHitTesting.zPriority(for: friend),
            MapPuckHitTesting.zPriority(for: selfPuck)
        )
    }

    func testPreferredHitReturnsOnlyContainingCandidate() {
        let candidates = [
            MapPuckHitTesting.Candidate(
                id: "a",
                center: CGPoint(x: 0, y: 0),
                radius: 20,
                zPriority: MapPuckHitTesting.ZPriority.friend
            ),
            MapPuckHitTesting.Candidate(
                id: "b",
                center: CGPoint(x: 100, y: 0),
                radius: 20,
                zPriority: MapPuckHitTesting.ZPriority.friend
            ),
        ]

        XCTAssertEqual(
            MapPuckHitTesting.preferredHit(among: candidates, at: CGPoint(x: 5, y: 0)),
            "a"
        )
        XCTAssertEqual(
            MapPuckHitTesting.preferredHit(among: candidates, at: CGPoint(x: 100, y: 5)),
            "b"
        )
        XCTAssertNil(
            MapPuckHitTesting.preferredHit(among: candidates, at: CGPoint(x: 50, y: 0))
        )
    }

    func testPreferredHitPrefersHigherZPriorityEvenWhenFarther() {
        // Tap is closer to A but both circles contain it; B is a hangout stacked above.
        let candidates = [
            MapPuckHitTesting.Candidate(
                id: "a",
                center: CGPoint(x: 0, y: 0),
                radius: 40,
                zPriority: MapPuckHitTesting.ZPriority.friend
            ),
            MapPuckHitTesting.Candidate(
                id: "b",
                center: CGPoint(x: 20, y: 0),
                radius: 40,
                zPriority: MapPuckHitTesting.ZPriority.hangoutCluster
            ),
        ]
        let tap = CGPoint(x: 5, y: 0) // closer to A

        XCTAssertEqual(
            MapPuckHitTesting.preferredHit(among: candidates, at: tap),
            "b"
        )
    }

    func testPreferredHitUsesCloserCenterWhenZPriorityTies() {
        let candidates = [
            MapPuckHitTesting.Candidate(
                id: "a",
                center: CGPoint(x: 0, y: 0),
                radius: 40,
                zPriority: MapPuckHitTesting.ZPriority.friend
            ),
            MapPuckHitTesting.Candidate(
                id: "b",
                center: CGPoint(x: 20, y: 0),
                radius: 40,
                zPriority: MapPuckHitTesting.ZPriority.friend
            ),
        ]

        XCTAssertEqual(
            MapPuckHitTesting.preferredHit(among: candidates, at: CGPoint(x: 5, y: 0)),
            "a"
        )
        XCTAssertEqual(
            MapPuckHitTesting.preferredHit(among: candidates, at: CGPoint(x: 18, y: 0)),
            "b"
        )
    }

    // MARK: - Fixtures

    private func samplePuck(id: String, kind: MapPuckKind) -> MapPuckData {
        MapPuckData(
            id: id,
            kind: kind,
            people: [
                FriendPuckData(
                    id: id,
                    name: id.capitalized,
                    avatarPlaceholder: "AB",
                    activity: "Coffee",
                    activitySymbolName: "cup.and.saucer.fill",
                    activityDisplayText: "Cafe",
                    availability: .freeNow,
                    venueStatusText: "At Cafe",
                    placeName: "Cafe"
                ),
            ],
            activity: "Coffee",
            availability: .freeNow,
            venueStatusText: "At Cafe",
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
            groupIDs: []
        )
    }

    private func sampleRegional(id: String, members: Int) -> RegionalPuckModel {
        RegionalPuckModel(
            id: id,
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
            memberCount: members,
            containsCurrentUser: false,
            containsJoinedGroup: false,
            activeCount: members,
            joinableCount: 0,
            busyCount: 0,
            dominantAvailability: .freeNow,
            representativeAvatars: [],
            regionName: "Mission",
            activityScore: 0.5,
            groupIDs: []
        )
    }
}
