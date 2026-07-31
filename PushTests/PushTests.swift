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

        XCTAssertEqual(items.map(\.title), ["Map", "Friends", "+", "Feed", "Pushes"])
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
            "Start push",
            "Add friend"
        ])
        XCTAssertEqual(items.map(\.subtitle), [
            "Send a social signal to your crew",
            "Invite someone to Push"
        ])
        XCTAssertEqual(items.map(\.symbolName), [
            "bolt.fill",
            "person.badge.plus"
        ])
        XCTAssertEqual(items.map(\.route), [
            .startPush,
            .addFriend
        ])
    }

    func testGlassStyleTokensExposeConsistentMaterialValues() throws {
        XCTAssertEqual(PushGlassStyle.materialPresenceOpacity, 0.68)
        XCTAssertEqual(PushGlassStyle.tintOpacity, 0.22)
        XCTAssertEqual(PushGlassStyle.strokeOpacity, 0.52)
        XCTAssertEqual(PushGlassStyle.strokeWidth, 0.8)
        XCTAssertEqual(PushGlassStyle.shadowOpacity, 0.18)
        XCTAssertEqual(PushGlassStyle.shadowRadius, 24)
        XCTAssertEqual(PushGlassStyle.shadowYOffset, 10)
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
        let scenarios = PuckLabFixtures.scenarios

        XCTAssertTrue(scenarios.contains { $0.title == "Together" && $0.friends.count == 2 })
        XCTAssertTrue(scenarios.contains { $0.title == "Small group" && $0.friends.count == 4 })
        XCTAssertFalse(scenarios.contains { $0.title == "Different states" })
    }

    func testPuckLabCoversRegionalVisualStates() throws {
        let regional = PuckLabFixtures.regionalScenarios

        XCTAssertEqual(regional.map(\.model.memberCount), [10, 5, 6, 16])
        XCTAssertTrue(regional.contains { $0.model.containsCurrentUser })
        XCTAssertTrue(regional.contains { $0.model.isSociallyActive && !$0.model.containsCurrentUser })
        XCTAssertTrue(regional.contains(where: \.isSelected))
        XCTAssertTrue(
            regional.allSatisfy {
                !$0.model.representativeAvatars.isEmpty
                    && $0.model.representativeAvatars.count <= 3
            }
        )
    }

    func testClusterLayoutKindSeparatesPairsFromGroups() throws {
        XCTAssertEqual(FriendClusterLayoutKind(friendsCount: 2), .pair)
        XCTAssertEqual(FriendClusterLayoutKind(friendsCount: 3), .smallGroup)
        XCTAssertEqual(FriendClusterLayoutKind(friendsCount: 4), .smallGroup)
    }

    func testHangoutScenariosUseOneSharedAvailabilityState() throws {
        let hangoutScenarios = PuckLabFixtures.scenarios.filter { $0.friends.count > 1 }

        for scenario in hangoutScenarios {
            let availabilityStates = Set(scenario.friends.map(\.availability))
            XCTAssertEqual(availabilityStates.count, 1, "\(scenario.title) should use one shared availability color")
        }
    }

    func testFriendGroupScenarioUsesFriendGroupPuckStyle() throws {
        let scenario = try XCTUnwrap(PuckLabFixtures.scenarios.first { $0.title == "Friend group" })

        XCTAssertEqual(scenario.puckStyle, .friendGroup)
        XCTAssertGreaterThan(scenario.friends.count, 3)
    }

    func testSingleFriendPuckExamplesCoverAvailabilityStates() throws {
        let examples = PuckLabFixtures.singleFriendScenarios

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
        let singleFriends = PuckLabFixtures.singleFriendScenarios.compactMap(\.friends.first)

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


    @MainActor
    private func loadedProfileViewModel() async -> ProfileViewModel {
        let viewModel = ProfileViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        return viewModel
    }

    @MainActor
    func testProfileDataDerivesFromCanonicalUser() async throws {
        let viewModel = await loadedProfileViewModel()
        let profile = viewModel.profile

        XCTAssertEqual(profile.name, "Manav")
        // Firstname-derived initials, consistent with all friends (documented change from "MK").
        XCTAssertEqual(profile.initials, "MA")
        XCTAssertEqual(profile.handle, "@manav")
        XCTAssertEqual(profile.imageAssetName, "assets/profile/manav.jpeg")
        XCTAssertEqual(profile.availability, .maybeDown)
        // Presence activity is independent of the availability chip.
        XCTAssertEqual(profile.activityTitle, "Park")
        XCTAssertEqual(profile.placeTitle, "Near North Park")
        XCTAssertEqual(profile.visibilityNote, "Visible to close friends for the next few hours.")
    }

    @MainActor
    func testProfileExposesAvailabilityOptions() async throws {
        let viewModel = await loadedProfileViewModel()
        let profile = viewModel.profile

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

    @MainActor
    func testProfileViewModelUpdatesSelectedAvailabilityLocally() async throws {
        let viewModel = await loadedProfileViewModel()
        let freeNow = try XCTUnwrap(viewModel.profile.availabilityOptions.first)

        XCTAssertEqual(viewModel.selectedAvailability, .maybeDown)

        viewModel.select(freeNow)

        XCTAssertEqual(viewModel.selectedAvailability, .freeNow)
        XCTAssertTrue(viewModel.isSelected(freeNow))
        XCTAssertFalse(viewModel.isSelected(viewModel.profile.availabilityOptions[1]))
    }

    @MainActor
    func testProfileViewModelExposesPhotoEditingSheet() async throws {
        let viewModel = await loadedProfileViewModel()

        XCTAssertFalse(viewModel.isPhotoEditorPresented)
        // Seed user has a bundled profile image.
        XCTAssertTrue(viewModel.hasProfilePhoto)

        viewModel.beginPhotoEditing()

        XCTAssertTrue(viewModel.isPhotoEditorPresented)
    }

    @MainActor
    func testProfileViewModelDefaultsGhostModeOff() async throws {
        let viewModel = await loadedProfileViewModel()

        XCTAssertFalse(viewModel.isGhostModeEnabled)
        XCTAssertEqual(viewModel.visibilitySummary, "Visible to close friends for the next few hours.")
    }

    @MainActor
    func testProfileViewModelSelectsGhostModeExclusively() async throws {
        let viewModel = await loadedProfileViewModel()
        let freeNow = try XCTUnwrap(viewModel.profile.availabilityOptions.first)
        let priorAvailability = viewModel.selectedAvailability

        viewModel.select(.ghostMode)
        // Ghost is orthogonal publish — allow a brief async LocationSession write-through.
        for _ in 0..<20 where !viewModel.isGhostModeEnabled {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertTrue(viewModel.isGhostModeEnabled)
        XCTAssertEqual(
            viewModel.visibilitySummary,
            "Hidden from friends' map and social context until you turn Ghost Mode off."
        )
        // Ghost never overwrites social availability (Busy+Ghost is allowed).
        XCTAssertEqual(viewModel.selectedAvailability, priorAvailability)

        viewModel.select(.availability(freeNow))
        for _ in 0..<20 where viewModel.selectedAvailability != .freeNow {
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        // Social availability updates; Ghost stays on (orthogonal publish flag).
        XCTAssertEqual(viewModel.selectedAvailability, .freeNow)
        XCTAssertTrue(viewModel.isGhostModeEnabled)
        // Status-option path still marks freeNow selected under Ghost.
        XCTAssertTrue(viewModel.isSelected(ProfileStatusOption.availability(freeNow)))
    }

    @MainActor
    func testProfileViewModelPersistsGhostModeAcrossReload() async throws {
        let container = AppDataContainer(seed: .standard())
        // Ghost is LocationSession publish flag, not availability `.ghost`.
        await container.locationSession?.setPresencePublishingEnabled(false)

        let viewModel = ProfileViewModel(container: container)
        await viewModel.load()

        XCTAssertTrue(viewModel.isGhostModeEnabled)
        XCTAssertEqual(
            viewModel.visibilitySummary,
            "Hidden from friends' map and social context until you turn Ghost Mode off."
        )
    }

    /// A profile's `chosenAvailability` can be outside the 3 quick-pick
    /// options (e.g. live Supabase data), so the header pill must reflect
    /// the real status rather than falsely falling back to Ghost Mode.
    @MainActor
    func testProfileHeaderReflectsAvailabilityOutsideQuickOptions() async throws {
        let seed = SeedData.standard()
        let widened = SeedData(
            currentUserID: seed.currentUserID, people: seed.people,
            acceptedFriendIDs: seed.acceptedFriendIDs, groups: seed.groups,
            memberships: seed.memberships, places: seed.places, statuses: seed.statuses,
            policies: seed.policies, plans: seed.plans, responses: seed.responses,
            hangouts: seed.hangouts, feedEvents: seed.feedEvents,
            friendRequests: seed.friendRequests,
            profile: UserProfile(
                personID: seed.profile.personID, handle: seed.profile.handle,
                chosenAvailability: .joinable, visibilityNote: seed.profile.visibilityNote,
                availabilityOptions: seed.profile.availabilityOptions,
                activityVisibility: seed.profile.activityVisibility,
                mapPreferences: seed.profile.mapPreferences,
                closeFriends: seed.profile.closeFriends, connectors: seed.profile.connectors
            )
        )
        let viewModel = ProfileViewModel(container: AppDataContainer(seed: widened))
        await viewModel.load()

        XCTAssertEqual(viewModel.selectedStatusTitle, "Joinable")
        XCTAssertFalse(viewModel.isGhostModeEnabled)
    }

    @MainActor
    func testProfileRoutesExposeSettingsAndPrivacyMetadata() async throws {
        let viewModel = await loadedProfileViewModel()

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

    @MainActor
    func testProfileViewModelEditsProfileBasicsLocally() async throws {
        let viewModel = await loadedProfileViewModel()

        viewModel.setProfileBasics(name: "Manny", handle: "@manny")

        XCTAssertEqual(viewModel.displayName, "Manny")
        XCTAssertEqual(viewModel.handle, "@manny")
        XCTAssertEqual(viewModel.initials, "MA")
    }

    @MainActor
    func testProfileViewModelTogglesActivityVisibilityLocally() async throws {
        let viewModel = await loadedProfileViewModel()

        XCTAssertTrue(try XCTUnwrap(viewModel.activityVisibility.first { $0.id == "place" }).isEnabled)

        viewModel.toggleActivityVisibility(id: "place")

        XCTAssertFalse(try XCTUnwrap(viewModel.activityVisibility.first { $0.id == "place" }).isEnabled)
    }

    @MainActor
    func testProfileConnectSectionExposesGSuiteCalendarFirst() async throws {
        let viewModel = await loadedProfileViewModel()
        let connector = try XCTUnwrap(viewModel.connectors.first)

        XCTAssertEqual(connector.id, "gsuite-calendar")
        XCTAssertEqual(connector.title, "GSuite Calendar")
        XCTAssertEqual(connector.symbolName, "calendar.badge.clock")
        XCTAssertEqual(connector.buttonTitle, "Connect with GSuite")
        XCTAssertTrue(connector.permissionCopy.contains("free/busy windows"))
        XCTAssertTrue(connector.permissionCopy.contains("Event titles"))
    }

    @MainActor
    func testProfileConnectAlertUsesAvailabilityOnlyCopy() async throws {
        let viewModel = await loadedProfileViewModel()
        let connector = try XCTUnwrap(viewModel.connectors.first)

        viewModel.connect(connector)

        XCTAssertEqual(viewModel.connectorAlert?.id, "gsuite-calendar")
        XCTAssertEqual(viewModel.connectorAlert?.title, "GSuite Calendar")
        XCTAssertEqual(
            viewModel.connectorAlert?.message,
            "This prototype does not start Google sign-in yet. The connector is modeled for availability-only access."
        )
    }

    func testMainMapRoutesFeedAndPlansExposeMetadata() throws {
        XCTAssertEqual(MainMapRoute.feed.id, "feed")
        XCTAssertEqual(MainMapRoute.feed.accessibilityLabel, "Feed")
        XCTAssertEqual(MainMapRoute.feed.systemImageName, "list.bullet")

        XCTAssertEqual(MainMapRoute.plans.id, "plans")
        XCTAssertEqual(MainMapRoute.plans.accessibilityLabel, "Pushes")
        XCTAssertEqual(MainMapRoute.plans.systemImageName, "calendar")
    }

    func testMainMapRoutesExposeStableProfileMetadata() throws {
        XCTAssertEqual(MainMapRoute.groups.id, "groups")
        XCTAssertEqual(MainMapRoute.groups.accessibilityLabel, "Friends")
        XCTAssertEqual(MainMapRoute.groups.systemImageName, "person.2.fill")

        XCTAssertEqual(MainMapRoute.profile.id, "profile")
        XCTAssertEqual(MainMapRoute.profile.accessibilityLabel, "Profile")
        XCTAssertEqual(MainMapRoute.profile.systemImageName, "person.crop.circle.fill")

        XCTAssertEqual(MainMapRoute.startPlan.id, "startPlan")
        XCTAssertEqual(MainMapRoute.startPlan.accessibilityLabel, "Start Push")
        XCTAssertEqual(MainMapRoute.startPlan.systemImageName, "calendar.badge.plus")

        XCTAssertEqual(MainMapRoute.addFriend.id, "addFriend")
        XCTAssertEqual(MainMapRoute.addFriend.accessibilityLabel, "Add Friend")
        XCTAssertEqual(MainMapRoute.addFriend.systemImageName, "person.badge.plus")
    }

    func testFriendPuckDataStoresLastUpdatedAndWithWhom() throws {
        let puck = FriendPuckData(
            name: "Ishan",
            avatarPlaceholder: "IS",
            profileImageAssetName: "assets/friends/ishan.png",
            activity: "Lunch",
            activitySymbolName: "fork.knife",
            activityDisplayText: "Souvla",
            availability: .joinable,
            venueStatusText: "At Souvla",
            lastUpdated: "Just now",
            withWhom: ["Viplove"]
        )

        XCTAssertEqual(puck.lastUpdated, "Just now")
        XCTAssertEqual(puck.withWhom, ["Viplove"])
    }

    func testFriendPuckDataDefaultsToJustNowAndNilWithWhom() throws {
        let puck = FriendPuckData(
            name: "Chitty",
            avatarPlaceholder: "CH",
            activity: "Coffee",
            activitySymbolName: "cup.and.saucer.fill",
            activityDisplayText: "Blue Bottle",
            availability: .freeNow,
            venueStatusText: "At Blue Bottle"
        )

        XCTAssertEqual(puck.lastUpdated, "Just now")
        XCTAssertNil(puck.withWhom)
    }

    func testCompactSheetTitleForSinglePersonUsesFullName() throws {
        let people = [
            FriendPuckData(
                name: "Chitty Patel", avatarPlaceholder: "CH", activity: "Coffee",
                activitySymbolName: "cup.and.saucer.fill", activityDisplayText: "Blue Bottle",
                availability: .freeNow, venueStatusText: "At Blue Bottle",
                locationLabel: "315 Linden St", placeName: "Blue Bottle"
            )
        ]
        XCTAssertEqual(
            FriendDetailSheetContent.multiPersonTitle(for: people),
            "Chitty Patel"
        )
    }

    func testGroupContextTitleAndSubtitleSplitVenue() throws {
        let people: [FriendPuckData] = [
            FriendPuckData(
                name: "Ishan", avatarPlaceholder: "IS", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "At Souvla",
                placeName: "Souvla"
            ),
            FriendPuckData(
                name: "Viplove", avatarPlaceholder: "VI", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "With Ishan",
                placeName: "Souvla"
            )
        ]
        let puck = MapPuckData(
            id: "puck-souvla",
            kind: .hangout,
            people: people,
            activity: "Lunch",
            availability: .joinable,
            venueStatusText: "At Souvla",
            coordinate: .init(latitude: 37.776, longitude: -122.424)
        )
        XCTAssertEqual(
            FriendDetailSheetContent.groupContextTitle(for: puck),
            "2 friends together"
        )
        XCTAssertEqual(
            FriendDetailSheetContent.groupContextSubtitle(for: puck),
            "At Souvla"
        )
        XCTAssertEqual(
            FriendDetailSheetContent.summaryTitle(for: puck),
            "2 friends together"
        )
    }

    func testGroupContextTitleTogetherWithoutVenue() throws {
        let people: [FriendPuckData] = (0..<3).map { i in
            FriendPuckData(
                name: "P\(i)", avatarPlaceholder: "P", activity: "Hang",
                activitySymbolName: "person.2.fill", activityDisplayText: "Hang",
                availability: .joinable, venueStatusText: "Together"
            )
        }
        let puck = MapPuckData(
            id: "puck-together",
            kind: .cluster,
            people: people,
            activity: "Hang",
            availability: .joinable,
            venueStatusText: "Together",
            coordinate: .init(latitude: 37.77, longitude: -122.42)
        )
        XCTAssertEqual(
            FriendDetailSheetContent.groupContextTitle(for: puck),
            "3 friends together"
        )
    }

    func testWhosHereOverflowThreshold() throws {
        XCTAssertFalse(FriendDetailSheetContent.needsWhosHereOverflow(memberCount: 6))
        XCTAssertTrue(FriendDetailSheetContent.needsWhosHereOverflow(memberCount: 7))
        XCTAssertEqual(FriendDetailSheetContent.whosHereOverflowCount(memberCount: 9), 4)
    }

    func testMultiPersonTitleForTwoPeopleUsesAmpersand() throws {
        let people: [FriendPuckData] = [
            FriendPuckData(
                name: "Ishan", avatarPlaceholder: "IS", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "At Souvla"
            ),
            FriendPuckData(
                name: "Viplove", avatarPlaceholder: "VI", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "With Ishan"
            )
        ]

        XCTAssertEqual(FriendDetailSheetContent.multiPersonTitle(for: people), "Ishan & Viplove")
        XCTAssertEqual(FriendDetailSheetContent.groupHeadline(for: people), "Ishan & Viplove")
    }

    func testMultiPersonTitleForThreePeopleListsNames() throws {
        let people: [FriendPuckData] = [
            FriendPuckData(
                name: "Ishan Patel", avatarPlaceholder: "IS", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "At Souvla"
            ),
            FriendPuckData(
                name: "Viplove Shah", avatarPlaceholder: "VI", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "At Souvla"
            ),
            FriendPuckData(
                name: "Rohan Mehta", avatarPlaceholder: "RO", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "At Souvla"
            )
        ]

        XCTAssertEqual(
            FriendDetailSheetContent.multiPersonTitle(for: people),
            "Ishan, Viplove & Rohan"
        )
    }

    func testMultiPersonTitleForFourPlusUsesOverflowCount() throws {
        let names = ["Ada", "Ben", "Cara", "Drew", "Eve"]
        let people: [FriendPuckData] = names.map { name in
            FriendPuckData(
                name: name, avatarPlaceholder: String(name.prefix(2)).uppercased(),
                activity: "Park", activitySymbolName: "leaf.fill",
                activityDisplayText: "Dolores", availability: .joinable,
                venueStatusText: "At Dolores"
            )
        }

        XCTAssertEqual(
            FriendDetailSheetContent.multiPersonTitle(for: people),
            "Ada, Ben + 3"
        )
    }

    func testMultiPersonTitleForEmptyPeopleFallsBack() throws {
        XCTAssertEqual(FriendDetailSheetContent.multiPersonTitle(for: []), "Group")
        XCTAssertEqual(FriendDetailSheetContent.groupHeadline(for: []), "Group")
    }

    func testMultiPersonActivityAndLocationLines() throws {
        let people: [FriendPuckData] = [
            FriendPuckData(
                name: "Ishan", avatarPlaceholder: "IS", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "At Souvla",
                locationLabel: "517 Hayes St", placeName: "Souvla"
            ),
            FriendPuckData(
                name: "Viplove", avatarPlaceholder: "VI", activity: "Lunch",
                activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                availability: .joinable, venueStatusText: "With Ishan",
                locationLabel: "517 Hayes St", placeName: "Souvla"
            )
        ]
        let puck = MapPuckData(
            id: "puck-souvla",
            kind: .hangout,
            people: people,
            activity: "Lunch",
            availability: .joinable,
            venueStatusText: "At Souvla",
            coordinate: .init(latitude: 37.776, longitude: -122.424)
        )

        XCTAssertEqual(
            FriendDetailSheetContent.multiPersonActivityLine(for: puck),
            "Lunch at Souvla"
        )
        XCTAssertEqual(
            FriendDetailSheetContent.multiPersonLocationDetail(for: puck),
            "517 Hayes St"
        )
        XCTAssertTrue(FriendDetailSheetContent.showsAskToJoin(for: puck))
    }

    func testMultiPersonActivityAvoidsRedundantParkAtDoloresParkLawn() throws {
        let people: [FriendPuckData] = [
            FriendPuckData(
                name: "Rohan", avatarPlaceholder: "RO", activity: "Park",
                activitySymbolName: "leaf.fill", activityDisplayText: "Dolores",
                availability: .joinable, venueStatusText: "Walking over",
                locationLabel: "Dolores Park, 19th St", placeName: "Dolores Park Lawn"
            ),
            FriendPuckData(
                name: "Ryan", avatarPlaceholder: "RY", activity: "Park",
                activitySymbolName: "leaf.fill", activityDisplayText: "Dolores",
                availability: .joinable, venueStatusText: "Free in 20",
                locationLabel: "Dolores Park, 19th St", placeName: "Dolores Park Lawn"
            ),
            FriendPuckData(
                name: "Pranay", avatarPlaceholder: "PR", activity: "Park",
                activitySymbolName: "leaf.fill", activityDisplayText: "Dolores",
                availability: .joinable, venueStatusText: "Maybe pulling up",
                locationLabel: "Dolores Park, 19th St", placeName: "Dolores Park Lawn"
            )
        ]
        let puck = MapPuckData(
            id: "puck-dolores",
            kind: .cluster,
            people: people,
            activity: "Park",
            availability: .joinable,
            venueStatusText: "At Dolores",
            coordinate: .init(latitude: 37.76, longitude: -122.43)
        )

        XCTAssertEqual(
            FriendDetailSheetContent.multiPersonActivityLine(for: puck),
            "At Dolores"
        )
        XCTAssertNil(
            FriendDetailSheetContent.multiPersonLocationDetail(for: puck),
            "Place-name addresses that echo the venue should stay hidden"
        )
    }

    func testShowsAskToJoinHiddenWhenBusyOrViewerIncluded() throws {
        let busy = MapPuckData(
            id: "busy",
            kind: .hangout,
            people: [
                FriendPuckData(
                    name: "A", avatarPlaceholder: "A", activity: "Work",
                    activitySymbolName: "briefcase.fill", activityDisplayText: "Office",
                    availability: .busy, venueStatusText: "At Office"
                ),
                FriendPuckData(
                    name: "B", avatarPlaceholder: "B", activity: "Work",
                    activitySymbolName: "briefcase.fill", activityDisplayText: "Office",
                    availability: .busy, venueStatusText: "At Office"
                )
            ],
            activity: "Work",
            availability: .busy,
            venueStatusText: "At Office",
            coordinate: .init(latitude: 37.77, longitude: -122.42)
        )
        XCTAssertFalse(FriendDetailSheetContent.showsAskToJoin(for: busy))

        let withSelf = MapPuckData(
            id: "with-self",
            kind: .hangout,
            people: [
                FriendPuckData(
                    name: "A", avatarPlaceholder: "A", activity: "Lunch",
                    activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                    availability: .joinable, venueStatusText: "At Souvla"
                ),
                FriendPuckData(
                    name: "You", avatarPlaceholder: "YO", activity: "Lunch",
                    activitySymbolName: "fork.knife", activityDisplayText: "Souvla",
                    availability: .joinable, venueStatusText: "At Souvla",
                    isCurrentUser: true
                )
            ],
            activity: "Lunch",
            availability: .joinable,
            venueStatusText: "At Souvla",
            coordinate: .init(latitude: 37.77, longitude: -122.42)
        )
        XCTAssertFalse(FriendDetailSheetContent.showsAskToJoin(for: withSelf))
    }

    @MainActor
    func testProfileBasicsFailureRollsBackAndRetries() async throws {
        let container = AppDataContainer(seed: .standard())
        let repository = ControllableProfileRepository(base: container.profile)
        let viewModel = ProfileViewModel(container: container, profile: repository)
        await viewModel.load()
        let originalName = viewModel.displayName
        let originalHandle = viewModel.handle
        let originalInitials = viewModel.initials
        repository.shouldFailWrites = true

        viewModel.setProfileBasics(name: "Manny", handle: "@manny")
        await waitUntil { viewModel.actionError != nil }

        XCTAssertEqual(viewModel.displayName, originalName)
        XCTAssertEqual(viewModel.handle, originalHandle)
        XCTAssertEqual(viewModel.initials, originalInitials)
        XCTAssertEqual(viewModel.actionError?.message, ProfileMutationCopy.basicsFailed)

        repository.shouldFailWrites = false
        viewModel.retryActionError()
        await waitUntil { repository.basicsWriteCount == 2 && viewModel.actionError == nil }

        XCTAssertEqual(viewModel.displayName, "Manny")
        XCTAssertEqual(viewModel.handle, "@manny")
        XCTAssertEqual(viewModel.initials, "MA")
    }

    @MainActor
    func testProfilePrivacyFailureRollsBackAndRetries() async throws {
        let container = AppDataContainer(seed: .standard())
        let repository = ControllableProfileRepository(base: container.profile)
        let viewModel = ProfileViewModel(container: container, profile: repository)
        await viewModel.load()
        let original = try XCTUnwrap(
            viewModel.activityVisibility.first { $0.id == "place" }
        ).isEnabled
        repository.shouldFailWrites = true

        viewModel.toggleActivityVisibility(id: "place")
        await waitUntil { viewModel.actionError != nil }

        XCTAssertEqual(
            try XCTUnwrap(viewModel.activityVisibility.first { $0.id == "place" }).isEnabled,
            original
        )
        XCTAssertEqual(viewModel.actionError?.message, ProfileMutationCopy.privacyFailed)

        repository.shouldFailWrites = false
        viewModel.retryActionError()
        await waitUntil { repository.privacyWriteCount == 2 && viewModel.actionError == nil }

        XCTAssertEqual(
            try XCTUnwrap(viewModel.activityVisibility.first { $0.id == "place" }).isEnabled,
            !original
        )
    }

    @MainActor
    func testProfileLoadFailureUsesFailedSurfacePhase() async {
        let container = AppDataContainer(seed: .standard())
        let repository = ControllableProfileRepository(base: container.profile)
        repository.shouldFailReads = true
        let viewModel = ProfileViewModel(container: container, profile: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.surfacePhase, .failed)
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Condition not met within \(timeout)s", file: file, line: line)
    }

}

private enum ProfileTestFailure: Error {
    case expected
}

@MainActor
final class ControllableProfileRepository: ProfileRepository {
    let base: ProfileRepository
    var shouldFailReads = false
    var shouldFailWrites = false
    private(set) var basicsWriteCount = 0
    private(set) var privacyWriteCount = 0

    init(base: ProfileRepository) {
        self.base = base
    }

    func userProfile() async throws -> UserProfile {
        if shouldFailReads { throw ProfileTestFailure.expected }
        return try await base.userProfile()
    }

    func updateBasics(displayName: String, handle: String) async throws {
        basicsWriteCount += 1
        if shouldFailWrites { throw ProfileTestFailure.expected }
        try await base.updateBasics(displayName: displayName, handle: handle)
    }

    func updatePrivacy(
        activityVisibility: [ProfileToggleItem],
        mapPreferences: [ProfileToggleItem],
        closeFriends: [ProfileToggleItem]
    ) async throws {
        privacyWriteCount += 1
        if shouldFailWrites { throw ProfileTestFailure.expected }
        try await base.updatePrivacy(
            activityVisibility: activityVisibility,
            mapPreferences: mapPreferences,
            closeFriends: closeFriends
        )
    }

    func updateProfilePhoto(jpegData: Data) async throws {
        try await base.updateProfilePhoto(jpegData: jpegData)
    }

    func removeProfilePhoto() async throws {
        try await base.removeProfilePhoto()
    }

    func needsPostAuthOnboarding() async throws -> Bool {
        try await base.needsPostAuthOnboarding()
    }

    func completeOnboarding() async throws {
        try await base.completeOnboarding()
    }
}
