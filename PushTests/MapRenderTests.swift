//
//  MapRenderTests.swift
//  PushTests
//

import CoreLocation
import MapKit
import XCTest
@testable import Push

final class MapRenderTests: XCTestCase {

    func testCloseZoomReturnsExactPucksAndSelfPuck() {
        let pucks = [puck(id: "nearby-a", personID: "a", latitude: 37.77, longitude: -122.42)]
        let selfPuck = selfPuck(latitude: 37.78, longitude: -122.41)
        let render = MapDisplayPuckBuilder.renderPucks(
            from: pucks,
            selfPuck: selfPuck,
            latitudeDelta: 0.08
        )

        XCTAssertEqual(render, [.friend(pucks[0]), .selfPuck(selfPuck)])
    }

    func testZoomedOutRangeImmediatelyUsesFinalRegionalPuck() throws {
        let individual = puck(id: "individual", personID: "a", latitude: 37.77, longitude: -122.42)
        let joinedGroup = puck(
            id: "joined-group", personID: "b", kind: .hangout,
            latitude: 37.78, longitude: -122.41, groupIDs: ["joined"]
        )
        let groupA = puck(id: "group-a", personID: "c", kind: .hangout, latitude: 37.79, longitude: -122.40)
        let groupB = puck(id: "group-b", personID: "d", kind: .cluster, latitude: 37.80, longitude: -122.39)
        let selfPuck = selfPuck(latitude: 37.76, longitude: -122.43)

        let render = MapDisplayPuckBuilder.renderPucks(
            from: [individual, joinedGroup, groupA, groupB],
            selfPuck: selfPuck,
            latitudeDelta: 4,
            currentUserGroupIDs: ["joined"]
        )

        let regional = try XCTUnwrap(render.onlyRegionalModel)
        XCTAssertEqual(regional.memberCount, 5)
        XCTAssertTrue(regional.containsCurrentUser)
        XCTAssertTrue(regional.containsJoinedGroup)
    }

    func testFarZoomClustersAllNearbyPucksIncludingSelf() throws {
        let pucks = [
            puck(id: "a", personID: "a", latitude: 37.77, longitude: -122.42),
            puck(id: "b", personID: "b", kind: .hangout, latitude: 37.80, longitude: -122.40, groupIDs: ["joined"])
        ]
        let selfPuck = selfPuck(latitude: 37.78, longitude: -122.41)
        let render = MapDisplayPuckBuilder.renderPucks(
            from: pucks,
            selfPuck: selfPuck,
            latitudeDelta: 12,
            currentUserGroupIDs: ["joined"]
        )
        let regional = try XCTUnwrap(render.onlyRegionalModel)

        XCTAssertEqual(render.count, 1)
        XCTAssertEqual(regional.memberCount, 3)
        XCTAssertTrue(regional.containsCurrentUser)
        XCTAssertTrue(regional.containsJoinedGroup)
    }

    func testStandaloneSelfPuckHidesWhenExactPuckAlreadyContainsCurrentUser() {
        let currentUserGroup = puck(
            id: "with-me",
            personID: "me",
            kind: .hangout,
            latitude: 37.77,
            longitude: -122.42,
            isCurrentUser: true
        )
        let render = MapDisplayPuckBuilder.renderPucks(
            from: [currentUserGroup],
            selfPuck: selfPuck(latitude: 37.78, longitude: -122.41),
            latitudeDelta: 0.08
        )

        XCTAssertEqual(render, [.smallGroup(currentUserGroup)])
    }

    func testRegionalModelDerivesCountsScoreAvatarsAndGroupIDs() throws {
        let active = puck(id: "active", personID: "a", availability: .freeNow, latitude: 37.77, longitude: -122.42, groupIDs: ["india"])
        let joinable = puck(id: "joinable", personID: "b", availability: .joinable, latitude: 37.78, longitude: -122.41, groupIDs: ["exec"])
        let busy = puck(id: "busy", personID: "c", availability: .busy, latitude: 37.79, longitude: -122.40, groupIDs: ["india"])
        let render = MapDisplayPuckBuilder.renderPucks(
            from: [active, joinable, busy],
            selfPuck: nil,
            latitudeDelta: 12,
            currentUserGroupIDs: ["exec"]
        )
        let regional = try XCTUnwrap(render.onlyRegionalModel)

        XCTAssertEqual(regional.activeCount, 2)
        XCTAssertEqual(regional.joinableCount, 1)
        XCTAssertEqual(regional.busyCount, 1)
        XCTAssertEqual(regional.dominantAvailability, .freeNow)
        XCTAssertEqual(regional.representativeAvatars.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(regional.groupIDs, ["exec", "india"])
        XCTAssertGreaterThan(regional.activityScore, 0)
    }

    func testFilteringBeforeClusteringUsesAlreadyFilteredPucks() throws {
        let india = puck(id: "india", personID: "a", latitude: 37.77, longitude: -122.42, groupIDs: ["india"])
        let exec = puck(id: "exec", personID: "b", latitude: 37.78, longitude: -122.41, groupIDs: ["exec"])
        let filtered = [india, exec].filter { $0.groupIDs.contains("india") }
        let render = MapDisplayPuckBuilder.renderPucks(
            from: filtered,
            selfPuck: nil,
            latitudeDelta: 12
        )

        let regional = try XCTUnwrap(render.onlyRegionalModel)
        XCTAssertEqual(regional.memberCount, 1)
        XCTAssertEqual(regional.groupIDs, ["india"])
    }

    func testVaguePresenceOnlyAppearsInRegionalClusterUsingVagueCoordinate() throws {
        let now = Date()
        let place = Place(
            id: "cafe", name: "Cafe", shortName: "Cafe", address: "1 Main",
            vagueLabel: "Mission", latitude: 37.77, longitude: -122.42,
            vagueLatitude: 37.7599, vagueLongitude: -122.4148
        )
        let presence = VisiblePresence(
            person: Person(id: "a", firstName: "a", imageAssetPath: nil),
            availability: .freeNow,
            activity: PresenceActivity(name: "Coffee", symbolName: "cup.and.saucer.fill"),
            statusNote: nil,
            placeInfo: .init(place: place, isVague: true),
            updatedAt: now,
            isCurrentUser: false
        )
        let sources = MapDisplayPuckBuilder.vagueRegionalSources(
            presences: [presence], groups: [], memberships: [], now: now
        )

        XCTAssertTrue(MapContentBuilder.pucks(presences: [presence], groups: [], memberships: [], now: now).isEmpty)
        XCTAssertEqual(MapDisplayPuckBuilder.renderPucks(from: [], selfPuck: nil, vagueSources: sources, latitudeDelta: 0.08), [])
        let regional = try XCTUnwrap(
            MapDisplayPuckBuilder.renderPucks(
                from: [], selfPuck: nil, vagueSources: sources, latitudeDelta: 12
            ).onlyRegionalModel
        )
        XCTAssertEqual(regional.coordinate.latitude, 37.7599, accuracy: 0.0001)
        XCTAssertEqual(regional.coordinate.longitude, -122.4148, accuracy: 0.0001)
    }

    @MainActor
    func testRegionalTapRequestsMapFocusAndDoesNotSelectSheetPuck() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        let regional = RegionalPuckModel(
            id: "regional-test",
            coordinate: CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
            memberCount: 4,
            containsCurrentUser: false,
            containsJoinedGroup: false,
            activeCount: 3,
            joinableCount: 1,
            busyCount: 1,
            dominantAvailability: .freeNow,
            representativeAvatars: [],
            regionName: "Mission",
            activityScore: 0.7,
            groupIDs: []
        )

        XCTAssertNil(viewModel.select(.regionalCluster(regional)))
        let focus = try XCTUnwrap(viewModel.mapFocusRequest)
        XCTAssertEqual(focus.region.center.latitude, 37.77, accuracy: 0.0001)
        XCTAssertEqual(focus.region.span.latitudeDelta, 0.06, accuracy: 0.0001)
    }

    @MainActor
    func testSelectingPersonFocusesTheirPuckAndClearsGroupFilter() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        let target = try XCTUnwrap(viewModel.filteredPucks.first)
        let personID = try XCTUnwrap(target.people.first?.id)
        viewModel.selectedFilterID = "michigan"

        let selected = try XCTUnwrap(viewModel.select(personID: personID))

        XCTAssertEqual(selected, target)
        XCTAssertEqual(viewModel.selectedFilterID, GroupFilterItem.allFriendsID)
        let focus = try XCTUnwrap(viewModel.mapFocusRequest)
        XCTAssertEqual(focus.region.center.latitude, target.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(focus.region.center.longitude, target.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(focus.region.span.latitudeDelta, 0.06, accuracy: 0.0001)
    }

    @MainActor
    func testSelectingPersonWithoutExactPuckDoesNothing() async {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        let priorFocus = viewModel.mapFocusRequest

        XCTAssertNil(viewModel.select(personID: "friend-without-visible-presence"))
        XCTAssertEqual(viewModel.mapFocusRequest, priorFocus)
    }

    private func puck(
        id: String,
        personID: String,
        kind: MapPuckKind = .individual,
        availability: FriendAvailabilityState = .freeNow,
        latitude: Double,
        longitude: Double,
        groupIDs: [String] = [],
        isCurrentUser: Bool = false
    ) -> MapPuckData {
        MapPuckData(
            id: id,
            kind: kind,
            people: [friend(personID, availability: availability, isCurrentUser: isCurrentUser)],
            activity: "Coffee",
            availability: availability,
            venueStatusText: "At Cafe",
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            groupIDs: groupIDs
        )
    }

    private func friend(
        _ id: String,
        availability: FriendAvailabilityState,
        isCurrentUser: Bool = false
    ) -> FriendPuckData {
        FriendPuckData(
            id: id,
            name: id.capitalized,
            avatarPlaceholder: String(id.prefix(2)).uppercased(),
            activity: "Coffee",
            activitySymbolName: "cup.and.saucer.fill",
            activityDisplayText: "Cafe",
            availability: availability,
            venueStatusText: "At Cafe",
            placeName: "Cafe",
            isCurrentUser: isCurrentUser
        )
    }

    private func selfPuck(latitude: Double, longitude: Double) -> SelfPuckData {
        SelfPuckData(
            id: "me",
            avatarPlaceholder: "ME",
            profileImageAssetName: nil,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }
}

private extension Array where Element == MapPuckRenderModel {
    var regionalModels: [RegionalPuckModel] {
        compactMap {
            if case .regionalCluster(let model) = $0 { return model }
            return nil
        }
    }

    var onlyRegionalModel: RegionalPuckModel? {
        regionalModels.count == 1 ? regionalModels[0] : nil
    }
}
