//
//  PresenceActivityPresentationTests.swift
//  PushTests
//
//  Issue #109 — canonical activity surfaces on map/friends/detail without
//  re-deriving composition or inventing place prefixes.
//

import XCTest
@testable import Push

final class PresenceActivityPresentationTests: XCTestCase {

    // MARK: - Canonical labels

    func testAtPlaceUsesActivityAndCompactBadge() {
        let fields = PresenceActivityPresentation.fields(
            activity: .atPlace("Crunch Fitness"),
            statusNote: "At Crunch Fitness",
            placeDisplayName: "Crunch Fitness"
        )
        XCTAssertEqual(fields.activityName, "At Crunch Fitness")
        XCTAssertEqual(fields.activitySymbolName, "mappin.and.ellipse")
        XCTAssertEqual(fields.activityDisplayText, "Crunch Fitness")
        XCTAssertEqual(fields.venueStatusText, "At Crunch Fitness")
    }

    func testMotionActivitiesUseNameAsBadgeAndStatusWhenNoteEmpty() {
        let cases: [(PresenceActivity, String)] = [
            (.chilling, "sofa.fill"),
            (.walking, "figure.walk"),
            (.driving, "car.fill"),
            (.moving, "figure.walk.motion"),
            (.nearby, "location.fill")
        ]
        for (activity, symbol) in cases {
            let fields = PresenceActivityPresentation.fields(
                activity: activity,
                statusNote: nil,
                placeDisplayName: activity.name // live synthetic place mirrors activity
            )
            XCTAssertEqual(fields.activityName, activity.name, activity.name)
            XCTAssertEqual(fields.activitySymbolName, symbol, activity.name)
            XCTAssertEqual(fields.activityDisplayText, activity.name, activity.name)
            // Must not invent "At Walking" from synthetic place names.
            XCTAssertEqual(fields.venueStatusText, activity.name, activity.name)
            XCTAssertFalse(
                fields.venueStatusText.hasPrefix("At \(activity.name)"),
                activity.name
            )
        }
    }

    func testStatusNoteWinsOverActivityForCuratedSocialCopy() {
        let fields = PresenceActivityPresentation.fields(
            activity: PresenceActivity(name: "Lunch", symbolName: "fork.knife"),
            statusNote: "With Ishan",
            placeDisplayName: "Souvla"
        )
        XCTAssertEqual(fields.venueStatusText, "With Ishan")
        XCTAssertEqual(fields.activityName, "Lunch")
        XCTAssertEqual(fields.activityDisplayText, "Lunch")
    }

    func testMissingActivityFallsBackToPlaceThenAvailability() {
        let withPlace = PresenceActivityPresentation.fields(
            activity: nil,
            statusNote: nil,
            placeDisplayName: "Blue Bottle",
            isVaguePlace: false,
            availabilityTitle: "Free now"
        )
        XCTAssertEqual(withPlace.activityName, "")
        XCTAssertEqual(withPlace.activitySymbolName, PresenceActivityPresentation.defaultSymbolName)
        XCTAssertEqual(withPlace.activityDisplayText, "Blue Bottle")
        XCTAssertEqual(withPlace.venueStatusText, "At Blue Bottle")

        let vague = PresenceActivityPresentation.fields(
            activity: nil,
            statusNote: nil,
            placeDisplayName: "North Park",
            isVaguePlace: true,
            availabilityTitle: "Maybe down"
        )
        XCTAssertEqual(vague.venueStatusText, "Near North Park")

        let availabilityOnly = PresenceActivityPresentation.fields(
            activity: PresenceActivity(name: "", symbolName: ""),
            statusNote: nil,
            placeDisplayName: nil,
            availabilityTitle: "Busy"
        )
        XCTAssertEqual(availabilityOnly.venueStatusText, "Busy")
        XCTAssertEqual(availabilityOnly.activitySymbolName, PresenceActivityPresentation.defaultSymbolName)
    }

    func testHiddenFieldsHaveNoLiveActivity() {
        let fields = PresenceActivityPresentation.hiddenFields()
        XCTAssertEqual(fields.activityName, "")
        XCTAssertEqual(fields.activityDisplayText, "")
        XCTAssertEqual(fields.venueStatusText, PresenceActivityPresentation.hiddenStatusText)
        XCTAssertEqual(fields.activitySymbolName, PresenceActivityPresentation.hiddenSymbolName)
    }

    func testDetailStatusLinePrefersVenueThenActivity() {
        XCTAssertEqual(
            PresenceActivityPresentation.detailStatusLine(
                activityName: "Walking",
                venueStatusText: "At Crunch Fitness"
            ),
            "At Crunch Fitness"
        )
        XCTAssertEqual(
            PresenceActivityPresentation.detailStatusLine(
                activityName: "Walking",
                venueStatusText: ""
            ),
            "Walking"
        )
        XCTAssertEqual(
            PresenceActivityPresentation.detailStatusLine(
                activityName: "",
                venueStatusText: "  "
            ),
            PresenceActivityPresentation.aroundFallback
        )
    }

    // MARK: - Builder integration (seed + live-shaped)

    func testFriendsBuilderSurfacesWalkingWithoutAtPrefix() throws {
        let person = Person(id: "walker", firstName: "walker", imageAssetPath: nil)
        let presence = VisiblePresence(
            person: person,
            availability: .freeNow,
            activity: .walking,
            statusNote: nil,
            placeInfo: VisiblePresence.VisiblePlaceInfo(
                place: Place(
                    id: "presence-walker",
                    name: "Walking",
                    shortName: "Walking",
                    address: "Shared location",
                    vagueLabel: "Nearby",
                    latitude: 37.77,
                    longitude: -122.42,
                    vagueLatitude: 37.77,
                    vagueLongitude: -122.42
                ),
                isVague: false
            ),
            updatedAt: Date(),
            isCurrentUser: false
        )
        let rows = FriendsContentBuilder.rows(
            friends: [person],
            presenceByPersonID: [person.id: presence],
            groupLabelByPersonID: [:],
            now: Date()
        )
        let friend = try XCTUnwrap(rows.first?.friend)
        XCTAssertEqual(friend.activity, "Walking")
        XCTAssertEqual(friend.activitySymbolName, "figure.walk")
        XCTAssertEqual(friend.activityDisplayText, "Walking")
        XCTAssertEqual(friend.venueStatusText, "Walking")
        XCTAssertEqual(friend.availability, .freeNow)
    }

    func testMapBuilderSurfacesAtPlaceOnIndividualPuck() throws {
        let person = Person(id: "gym", firstName: "ram", imageAssetPath: nil)
        let place = Place(
            id: "crunch",
            name: "Crunch Fitness",
            shortName: "Crunch",
            address: "100 Gym St",
            vagueLabel: "Mission",
            latitude: 37.76,
            longitude: -122.42,
            vagueLatitude: 37.76,
            vagueLongitude: -122.42
        )
        let presence = VisiblePresence(
            person: person,
            availability: .busy,
            activity: .atPlace("Crunch Fitness"),
            statusNote: "At Crunch Fitness",
            placeInfo: VisiblePresence.VisiblePlaceInfo(place: place, isVague: false),
            updatedAt: Date(),
            isCurrentUser: false
        )
        let pucks = MapContentBuilder.pucks(
            presences: [presence],
            groups: [],
            memberships: [],
            now: Date()
        )
        let puck = try XCTUnwrap(pucks.first)
        let friend = try XCTUnwrap(puck.people.first)
        XCTAssertEqual(puck.activity, "At Crunch Fitness")
        XCTAssertEqual(puck.venueStatusText, "At Crunch Fitness")
        XCTAssertEqual(friend.activity, "At Crunch Fitness")
        XCTAssertEqual(friend.activitySymbolName, "mappin.and.ellipse")
        XCTAssertEqual(friend.activityDisplayText, "Crunch")
        XCTAssertEqual(friend.venueStatusText, "At Crunch Fitness")
        XCTAssertEqual(friend.availability, .busy)
    }

    func testGroupMemberHidesUnpublishedActivity() throws {
        let person = Person(id: "ghost", firstName: "ghost", imageAssetPath: nil)
        let status = PresenceStatus(
            id: "status-ghost",
            personID: person.id,
            availability: .freeNow,
            activity: .walking,
            placeID: nil,
            statusNote: nil,
            confidence: .high,
            observedAt: Date(),
            updatedAt: Date(),
            expiresAt: nil,
            source: .inference,
            isPublished: false
        )
        let members = GroupContentBuilder.members(
            groupID: "g1",
            memberships: [
                GroupMembership(
                    id: "m1",
                    personID: person.id,
                    groupID: "g1",
                    role: .member,
                    sharingLevel: .full,
                    membershipStatus: .active,
                    joinedAt: Date()
                )
            ],
            people: [person.id: person],
            statuses: [person.id: status]
        )
        let member = try XCTUnwrap(members.first)
        XCTAssertEqual(member.venueStatusText, PresenceActivityPresentation.hiddenStatusText)
        XCTAssertEqual(member.activitySymbolName, PresenceActivityPresentation.hiddenSymbolName)
        XCTAssertEqual(member.availability, .freeNow)
    }

    func testProfileActivityTitleUsesPresenceNotAvailability() {
        let person = Person(id: SeedIDs.currentUser, firstName: "manav", imageAssetPath: nil)
        let place = Place(
            id: "north-park",
            name: "North Park",
            shortName: "North Park",
            address: "North Park",
            vagueLabel: "North Park",
            latitude: 37.76,
            longitude: -122.42,
            vagueLatitude: 37.76,
            vagueLongitude: -122.42
        )
        let presence = VisiblePresence(
            person: person,
            availability: .maybeDown,
            activity: .chilling,
            statusNote: nil,
            placeInfo: VisiblePresence.VisiblePlaceInfo(place: place, isVague: true),
            updatedAt: Date(),
            isCurrentUser: true
        )
        let profile = UserProfile(
            personID: person.id,
            handle: "@manav",
            chosenAvailability: .maybeDown,
            visibilityNote: "Visible",
            availabilityOptions: ProfileScaffolding.availabilityOptions,
            activityVisibility: ProfileScaffolding.activityVisibility,
            mapPreferences: ProfileScaffolding.mapPreferences,
            closeFriends: ProfileScaffolding.closeFriends,
            connectors: ProfileScaffolding.connectors
        )
        let data = ProfileContentBuilder.profileData(
            profile: profile,
            person: person,
            presence: presence
        )
        XCTAssertEqual(data.availability, .maybeDown)
        XCTAssertEqual(data.activityTitle, "Chilling")
        XCTAssertEqual(data.placeTitle, "Near North Park")
    }

    func testFriendDetailStatusLineDoesNotInventPrefixes() {
        let friend = FriendPuckData(
            name: "Chitty",
            avatarPlaceholder: "CH",
            activity: "Coffee",
            activitySymbolName: "cup.and.saucer.fill",
            activityDisplayText: "Coffee",
            availability: .freeNow,
            venueStatusText: "Coffee",
            placeName: "Blue Bottle"
        )
        let viewData = FriendDetailViewData(friend: friend)
        XCTAssertEqual(viewData.statusLine, "Coffee")

        let walking = FriendPuckData(
            name: "Walker",
            avatarPlaceholder: "WA",
            activity: "Walking",
            activitySymbolName: "figure.walk",
            activityDisplayText: "Walking",
            availability: .freeNow,
            venueStatusText: "Walking"
        )
        XCTAssertEqual(FriendDetailViewData(friend: walking).statusLine, "Walking")

        let atPlace = FriendPuckData(
            name: "Ram",
            avatarPlaceholder: "RA",
            activity: "At Crunch Fitness",
            activitySymbolName: "mappin.and.ellipse",
            activityDisplayText: "Crunch Fitness",
            availability: .busy,
            venueStatusText: "At Crunch Fitness",
            placeName: "Crunch Fitness"
        )
        XCTAssertEqual(FriendDetailViewData(friend: atPlace).statusLine, "At Crunch Fitness")
    }
}
