//
//  PushTests.swift
//  PushTests
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import XCTest
@testable import Push

final class PushTests: XCTestCase {

    func testBottomNavigationItemsExposePlaceholderTabs() throws {
        let items = BottomNavigationItem.allCases

        XCTAssertEqual(items.map(\.title), ["Map", "Group", "+", "Feed", "Plans"])
        XCTAssertEqual(items.map(\.systemImageName), [
            "map.fill",
            "person.2.fill",
            "plus",
            "list.bullet",
            "calendar"
        ])
        XCTAssertEqual(items.filter(\.isPrimaryAction), [.create])
    }

    func testCreateActionMenuItemsExposeRequiredCopy() throws {
        let items = CreateActionMenuItem.allCases

        XCTAssertEqual(items.map(\.title), [
            "Start plan",
            "Add friend"
        ])
        XCTAssertEqual(items.map(\.subtitle), [
            "Create a plan with friends",
            "Invite someone to Push"
        ])
        XCTAssertEqual(items.map(\.symbolName), [
            "calendar.badge.plus",
            "person.badge.plus"
        ])
        XCTAssertEqual(items.map(\.route), [
            .startPlan,
            .addFriend
        ])
    }

    func testFriendGroupFiltersExposeMockDropdownOptions() throws {
        XCTAssertEqual(FriendGroupFilter.allCases.map(\.title), [
            "All Friends",
            "India",
            "Exec",
            "Michigan"
        ])
    }

    func testGlassStyleTokensExposeConsistentMaterialValues() throws {
        XCTAssertEqual(PushGlassStyle.materialPresenceOpacity, 0.72)
        XCTAssertEqual(PushGlassStyle.tintOpacity, 0.24)
        XCTAssertEqual(PushGlassStyle.strokeOpacity, 0.62)
        XCTAssertEqual(PushGlassStyle.strokeWidth, 0.8)
        XCTAssertEqual(PushGlassStyle.shadowOpacity, 0.24)
        XCTAssertEqual(PushGlassStyle.shadowRadius, 26)
        XCTAssertEqual(PushGlassStyle.shadowYOffset, 12)
    }

    func testControlStyleTokensExposeSharedAccentBehavior() throws {
        XCTAssertEqual(PushControlStyle.activeFillOpacity, 1)
        XCTAssertEqual(PushControlStyle.inactiveForegroundOpacity, 0.7)
        XCTAssertEqual(PushControlStyle.primaryStrokeOpacity, 0.72)
        XCTAssertEqual(PushControlStyle.primaryGlowOpacity, 0.34)
    }

    func testAvailabilityStatesExposeDisplayMetadata() throws {
        XCTAssertEqual(FriendAvailabilityState.freeNow.title, "Free now")
        XCTAssertEqual(FriendAvailabilityState.freeNow.symbolName, "sparkles")
        XCTAssertEqual(FriendAvailabilityState.freeNow.colorName, "green")
        XCTAssertEqual(FriendAvailabilityState.freeNow.priority, 0)

        XCTAssertEqual(FriendAvailabilityState.maybeDown.title, "Maybe down")
        XCTAssertEqual(FriendAvailabilityState.maybeDown.colorName, "yellow")

        XCTAssertEqual(FriendAvailabilityState.joinable.title, "Joinable")
        XCTAssertEqual(FriendAvailabilityState.joinable.symbolName, "figure.wave")
        XCTAssertEqual(FriendAvailabilityState.joinable.colorName, "blue")
        XCTAssertEqual(FriendAvailabilityState.joinable.priority, 1)

        XCTAssertEqual(FriendAvailabilityState.busy.title, "Busy")
        XCTAssertEqual(FriendAvailabilityState.busy.colorName, "orange")

        XCTAssertEqual(FriendAvailabilityState.driving.title, "Driving / ETA")
        XCTAssertEqual(FriendAvailabilityState.driving.symbolName, "car.fill")
        XCTAssertEqual(FriendAvailabilityState.driving.colorName, "cyan")
        XCTAssertEqual(FriendAvailabilityState.driving.priority, 5)

        XCTAssertEqual(FriendAvailabilityState.unavailable.title, "Unavailable")
        XCTAssertEqual(FriendAvailabilityState.unavailable.symbolName, "minus.circle.fill")
        XCTAssertEqual(FriendAvailabilityState.unavailable.colorName, "gray")
        XCTAssertEqual(FriendAvailabilityState.unavailable.priority, 6)
    }

    func testMockPuckScenariosCoverSinglePairAndSmallGroup() throws {
        let scenarios = PuckLabMockData.scenarios

        XCTAssertTrue(scenarios.contains { $0.title == "Together" && $0.friends.count == 2 })
        XCTAssertTrue(scenarios.contains { $0.title == "Small group" && $0.friends.count == 4 })
        XCTAssertFalse(scenarios.contains { $0.title == "Different states" })
    }

    func testClusterLayoutKindSeparatesPairsFromGroups() throws {
        XCTAssertEqual(FriendClusterLayoutKind(friendsCount: 2), .pair)
        XCTAssertEqual(FriendClusterLayoutKind(friendsCount: 3), .smallGroup)
        XCTAssertEqual(FriendClusterLayoutKind(friendsCount: 4), .smallGroup)
    }

    func testHangoutScenariosUseOneSharedAvailabilityState() throws {
        let hangoutScenarios = PuckLabMockData.scenarios.filter { $0.friends.count > 1 }

        for scenario in hangoutScenarios {
            let availabilityStates = Set(scenario.friends.map(\.availability))
            XCTAssertEqual(availabilityStates.count, 1, "\(scenario.title) should use one shared availability color")
        }
    }

    func testFriendGroupScenarioUsesFriendGroupPuckStyle() throws {
        let scenario = try XCTUnwrap(PuckLabMockData.scenarios.first { $0.title == "Friend group" })

        XCTAssertEqual(scenario.puckStyle, .friendGroup)
        XCTAssertGreaterThan(scenario.friends.count, 3)
    }

    func testSingleFriendPuckExamplesCoverAvailabilityStates() throws {
        let examples = PuckLabMockData.singleFriendScenarios

        XCTAssertEqual(examples.map(\.title), [
            "Free now",
            "Maybe down",
            "Joinable",
            "Busy-ish",
            "Driving",
            "Unavailable"
        ])
        XCTAssertEqual(examples.map { $0.friends.count }, [1, 1, 1, 1, 1, 1])
        XCTAssertEqual(examples.compactMap { $0.friends.first?.availability }, [
            .freeNow,
            .maybeDown,
            .joinable,
            .busy,
            .driving,
            .unavailable
        ])
    }

    func testMockPuckActivitiesPreferSpecificDisplayText() throws {
        let singleFriends = PuckLabMockData.singleFriendScenarios.compactMap(\.friends.first)

        XCTAssertEqual(singleFriends.map(\.activityDisplayText), [
            "Blue Bottle",
            "Dolores",
            "Crunch",
            "Cotijas",
            "Driving",
            "Work"
        ])
        XCTAssertEqual(singleFriends.map(\.activitySymbolName), [
            "cup.and.saucer.fill",
            "leaf.fill",
            "dumbbell.fill",
            "fork.knife",
            "car.fill",
            "laptopcomputer"
        ])
        XCTAssertEqual(singleFriends.first?.name, "Chitty")
        XCTAssertEqual(singleFriends.first?.avatarPlaceholder, "CH")
    }

    func testFriendPuckDataStoresOptionalProfileImageAssetName() throws {
        let friend = FriendPuckData(
            name: "Chitty",
            avatarPlaceholder: "CH",
            profileImageAssetName: "assets/friends/chitty.png",
            activity: "Coffee",
            activitySymbolName: "cup.and.saucer.fill",
            activityDisplayText: "Blue Bottle",
            availability: .freeNow,
            venueStatusText: "At Blue Bottle"
        )

        XCTAssertEqual(friend.profileImageAssetName, "assets/friends/chitty.png")
    }

    func testMapPuckMockDataContainsRequiredPuckMix() throws {
        let pucks = MapPuckMockData.pucks

        XCTAssertEqual(pucks.count, 5)
        XCTAssertEqual(pucks.filter { $0.kind == .individual }.count, 2)
        XCTAssertEqual(pucks.filter { $0.kind == .hangout }.count, 1)
        XCTAssertEqual(pucks.filter { $0.kind == .cluster }.count, 1)
        XCTAssertEqual(pucks.filter { $0.kind == .friendGroup }.count, 1)
        XCTAssertTrue(pucks.allSatisfy { !$0.people.isEmpty })
        XCTAssertTrue(pucks.allSatisfy { $0.coordinate.latitude != 0 && $0.coordinate.longitude != 0 })
    }

    func testMapPuckMockDataUsesAvailableAssetNames() throws {
        let pucks = MapPuckMockData.pucks
        let assetNames = Set(pucks.flatMap { $0.people.compactMap(\.profileImageAssetName) })

        XCTAssertTrue(assetNames.isSubset(of: [
            "assets/friends/chitty.png",
            "assets/friends/nitin.png",
            "assets/friends/ishan.png",
            "assets/friends/viplove.png",
            "assets/friends/ram.png",
            "assets/friends/rohan.png",
            "assets/friends/ryan.png",
            "assets/friends/pranay.png",
            "assets/friends/ohm.png",
            "assets/friends/roh.png",
            "assets/groups/Exec/ram.png"
        ]))
        XCTAssertTrue(assetNames.contains("assets/friends/chitty.png"))
        XCTAssertTrue(assetNames.contains("assets/friends/nitin.png"))
        XCTAssertTrue(assetNames.contains("assets/friends/ishan.png"))
        XCTAssertTrue(assetNames.contains("assets/groups/Exec/ram.png"))
    }

    func testProfileMockDataExposesCurrentUserIdentity() throws {
        let profile = ProfileMockData.currentUser

        XCTAssertEqual(profile.name, "Manav")
        XCTAssertEqual(profile.initials, "MK")
        XCTAssertEqual(profile.handle, "@manav")
        XCTAssertEqual(profile.imageAssetName, "assets/profile/manav.jpeg")
        XCTAssertEqual(profile.availability, .maybeDown)
        XCTAssertEqual(profile.activityTitle, "Maybe down")
        XCTAssertEqual(profile.placeTitle, "Near Hayes Valley")
        XCTAssertEqual(profile.visibilityNote, "Visible to close friends for the next few hours.")
    }

    func testProfileMockDataExposesAvailabilityOptions() throws {
        let profile = ProfileMockData.currentUser
        let viewModel = ProfileViewModel(profile: profile)

        XCTAssertEqual(profile.availabilityOptions.map(\.availability), [
            .freeNow,
            .maybeDown,
            .busy
        ])
        XCTAssertEqual(profile.availabilityOptions.map(\.title), [
            "Free now",
            "Maybe down",
            "Busy"
        ])
        XCTAssertEqual(viewModel.statusOptions.map(\.title), [
            "Ghost Mode",
            "Free now",
            "Maybe down",
            "Busy"
        ])
        XCTAssertTrue(viewModel.isSelected(profile.availabilityOptions[1]))
    }

    func testProfileViewModelUpdatesSelectedAvailabilityLocally() throws {
        let profile = ProfileMockData.currentUser
        let viewModel = ProfileViewModel(profile: profile)
        let freeNow = try XCTUnwrap(profile.availabilityOptions.first)

        XCTAssertEqual(viewModel.selectedAvailability, .maybeDown)

        viewModel.select(freeNow)

        XCTAssertEqual(viewModel.selectedAvailability, .freeNow)
        XCTAssertTrue(viewModel.isSelected(freeNow))
        XCTAssertFalse(viewModel.isSelected(profile.availabilityOptions[1]))
    }

    func testProfileViewModelExposesPhotoEditingPlaceholder() throws {
        let viewModel = ProfileViewModel()

        XCTAssertFalse(viewModel.isPhotoEditorPresented)

        viewModel.beginPhotoEditing()

        XCTAssertTrue(viewModel.isPhotoEditorPresented)
    }

    func testProfileViewModelDefaultsGhostModeOff() throws {
        let viewModel = ProfileViewModel()

        XCTAssertFalse(viewModel.isGhostModeEnabled)
        XCTAssertEqual(viewModel.visibilitySummary, "Visible to close friends for the next few hours.")
    }

    func testProfileViewModelSelectsGhostModeExclusively() throws {
        let viewModel = ProfileViewModel()
        let freeNow = try XCTUnwrap(viewModel.profile.availabilityOptions.first)

        viewModel.select(.ghostMode)

        XCTAssertTrue(viewModel.isGhostModeEnabled)
        XCTAssertEqual(
            viewModel.visibilitySummary,
            "Hidden from friends' map and social context until you turn Ghost Mode off."
        )
        XCTAssertEqual(viewModel.selectedAvailability, .maybeDown)
        XCTAssertFalse(viewModel.isSelected(freeNow))

        viewModel.select(.availability(freeNow))

        XCTAssertFalse(viewModel.isGhostModeEnabled)
        XCTAssertTrue(viewModel.isSelected(freeNow))
        XCTAssertEqual(viewModel.selectedAvailability, .freeNow)
    }

    func testProfileRoutesExposeSettingsAndPrivacyMetadata() throws {
        let viewModel = ProfileViewModel()

        XCTAssertEqual(viewModel.settingsRoutes.map(\.id), [
            "edit-profile",
            "activity-visibility",
            "map-preferences"
        ])
        XCTAssertEqual(viewModel.settingsRoutes.map(\.title), [
            "Edit profile",
            "Activity visibility",
            "Map preferences"
        ])
        XCTAssertEqual(viewModel.settingsRoutes.map(\.symbolName), [
            "pencil",
            "eye.fill",
            "map.fill"
        ])
        XCTAssertEqual(viewModel.settingsRoutes.map(\.section), Array(repeating: .settings, count: 3))

        XCTAssertEqual(viewModel.privacyRoutes.map(\.id), [
            "close-friends"
        ])
        XCTAssertEqual(viewModel.privacyRoutes.map(\.title), [
            "Close Friends"
        ])
        XCTAssertEqual(viewModel.privacyRoutes.map(\.symbolName), [
            "person.2.fill"
        ])
        XCTAssertEqual(viewModel.privacyRoutes.map(\.section), Array(repeating: .privacy, count: 1))
    }

    func testProfileViewModelEditsProfileBasicsLocally() throws {
        let viewModel = ProfileViewModel()

        viewModel.setProfileBasics(name: "Manny", handle: "@manny", initials: "MN")

        XCTAssertEqual(viewModel.displayName, "Manny")
        XCTAssertEqual(viewModel.handle, "@manny")
        XCTAssertEqual(viewModel.initials, "MN")
    }

    func testProfileViewModelTogglesActivityVisibilityLocally() throws {
        let viewModel = ProfileViewModel()

        XCTAssertTrue(try XCTUnwrap(viewModel.activityVisibility.first { $0.id == "place" }).isEnabled)

        viewModel.toggleActivityVisibility(id: "place")

        XCTAssertFalse(try XCTUnwrap(viewModel.activityVisibility.first { $0.id == "place" }).isEnabled)
    }

    func testProfileConnectSectionExposesGSuiteCalendarFirst() throws {
        let connector = try XCTUnwrap(ProfileViewModel().connectors.first)

        XCTAssertEqual(connector.id, "gsuite-calendar")
        XCTAssertEqual(connector.title, "GSuite Calendar")
        XCTAssertEqual(connector.symbolName, "calendar.badge.clock")
        XCTAssertEqual(connector.buttonTitle, "Connect with GSuite")
        XCTAssertTrue(connector.permissionCopy.contains("free/busy windows"))
        XCTAssertTrue(connector.permissionCopy.contains("Event titles"))
    }

    func testProfileConnectAlertUsesAvailabilityOnlyCopy() throws {
        let viewModel = ProfileViewModel()
        let connector = try XCTUnwrap(viewModel.connectors.first)

        viewModel.connect(connector)

        XCTAssertEqual(viewModel.connectorAlert?.id, "gsuite-calendar")
        XCTAssertEqual(viewModel.connectorAlert?.title, "GSuite Calendar")
        XCTAssertEqual(
            viewModel.connectorAlert?.message,
            "This prototype does not start Google sign-in yet. The connector is modeled for availability-only access."
        )
    }

    func testMainMapRoutesExposeStableProfileMetadata() throws {
        XCTAssertEqual(MainMapRoute.groups.id, "groups")
        XCTAssertEqual(MainMapRoute.groups.accessibilityLabel, "Groups")
        XCTAssertEqual(MainMapRoute.groups.systemImageName, "person.2.fill")

        XCTAssertEqual(MainMapRoute.profile.id, "profile")
        XCTAssertEqual(MainMapRoute.profile.accessibilityLabel, "Profile")
        XCTAssertEqual(MainMapRoute.profile.systemImageName, "person.crop.circle.fill")

        XCTAssertEqual(MainMapRoute.startPlan.id, "startPlan")
        XCTAssertEqual(MainMapRoute.startPlan.accessibilityLabel, "Start Plan")
        XCTAssertEqual(MainMapRoute.startPlan.systemImageName, "calendar.badge.plus")

        XCTAssertEqual(MainMapRoute.addFriend.id, "addFriend")
        XCTAssertEqual(MainMapRoute.addFriend.accessibilityLabel, "Add Friend")
        XCTAssertEqual(MainMapRoute.addFriend.systemImageName, "person.badge.plus")
    }

}
