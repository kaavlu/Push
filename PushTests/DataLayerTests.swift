//
//  DataLayerTests.swift
//  PushTests
//

import XCTest
@testable import Push

final class DataLayerTests: XCTestCase {

    func testPersonDerivesDisplayNameAndInitials() {
        let person = Person(id: "chitty", firstName: "chitty", imageAssetPath: "assets/friends/chitty.png")
        XCTAssertEqual(person.displayName, "Chitty")
        XCTAssertEqual(person.initials, "CH")
    }

    func testFriendGroupDerivesInitials() {
        let group = FriendGroup(id: "michigan", name: "Michigan", imageAssetPath: nil)
        XCTAssertEqual(group.initials, "M")
    }

    func testAvailabilityStateIsCodable() throws {
        let data = try JSONEncoder().encode(FriendAvailabilityState.freeNow)
        let decoded = try JSONDecoder().decode(FriendAvailabilityState.self, from: data)
        XCTAssertEqual(decoded, .freeNow)
    }

    func testLoadStateExposesLoadedValue() {
        XCTAssertEqual(LoadState.loaded(3).value, 3)
        XCTAssertNil(LoadState<Int>.loading.value)
    }

    // MARK: - Seed integrity

    func testSeedReferentialIntegrity() {
        let seed = SeedData.standard()
        let personIDs = Set(seed.people.map(\.id))
        let groupIDs = Set(seed.groups.map(\.id))
        let placeIDs = Set(seed.places.map(\.id))
        let planIDs = Set(seed.plans.map(\.id))

        XCTAssertTrue(personIDs.contains(seed.currentUserID))
        for membership in seed.memberships {
            XCTAssertTrue(personIDs.contains(membership.personID), membership.id)
            XCTAssertTrue(groupIDs.contains(membership.groupID), membership.id)
        }
        for status in seed.statuses {
            XCTAssertTrue(personIDs.contains(status.personID), status.id)
            if let placeID = status.placeID { XCTAssertTrue(placeIDs.contains(placeID), status.id) }
        }
        for plan in seed.plans {
            XCTAssertTrue(groupIDs.contains(plan.groupID), plan.id)
            XCTAssertTrue(personIDs.contains(plan.creatorID), plan.id)
            XCTAssertTrue(placeIDs.contains(plan.placeID), plan.id)
        }
        for response in seed.responses {
            XCTAssertTrue(planIDs.contains(response.pushID), response.id)
            XCTAssertTrue(personIDs.contains(response.personID), response.id)
        }
        for hangout in seed.hangouts {
            for pid in hangout.participantIDs { XCTAssertTrue(personIDs.contains(pid), hangout.id) }
        }
        for event in seed.feedEvents {
            for pid in event.actorIDs { XCTAssertTrue(personIDs.contains(pid), event.id) }
        }
    }

    func testSeedHasExactlyOneStatusPerPerson() {
        let seed = SeedData.standard()
        let statusPersonIDs = seed.statuses.map(\.personID)
        XCTAssertEqual(statusPersonIDs.count, Set(statusPersonIDs).count)
        XCTAssertEqual(Set(statusPersonIDs), Set(seed.people.map(\.id)))
    }

    func testSeedPoliciesAreFullVisibilityDefaults() {
        let seed = SeedData.standard()
        XCTAssertEqual(Set(seed.policies.map(\.ownerPersonID)), Set(seed.people.map(\.id)))
        XCTAssertTrue(seed.policies.allSatisfy { $0.audienceType == .globalDefault })
        XCTAssertTrue(seed.policies.allSatisfy { $0.locationVisibility == .exact })
    }

    func testSeedRamIsOnlyAtCrunch() {
        let seed = SeedData.standard()
        let ram = seed.statuses.filter { $0.personID == "ram" }
        XCTAssertEqual(ram.count, 1)
        XCTAssertEqual(ram.first?.placeID, "crunch")
    }

    // MARK: - Repositories

    @MainActor
    func testRepositoriesServeSeededData() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertEqual(friends.count, 10)
        XCTAssertFalse(friends.contains { $0.id == "manav" })
        let user = try await container.friends.currentUser()
        XCTAssertEqual(user.id, "manav")
        let groups = try await container.groups.groups()
        XCTAssertEqual(groups.map(\.id), ["india", "exec", "michigan"])
        let plans = try await container.pushes.activePlans()
        XCTAssertEqual(plans.count, 5)
    }

    @MainActor
    func testSetCurrentUserResponseUpsertsRow() async throws {
        let container = AppDataContainer(seed: .standard())
        try await container.pushes.setCurrentUserResponse(planID: "food-tonight", response: .in)
        let responses = try await container.pushes.responses()
        let mine = responses.first { $0.pushID == "food-tonight" && $0.personID == "manav" }
        XCTAssertEqual(mine?.response, .in)
    }

    // MARK: - MapViewModel

    @MainActor
    func testMapViewModelLoadsPucksAndFilters() async throws {
        let viewModel = MapViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        XCTAssertEqual(viewModel.loadState.value?.count, 5)
        XCTAssertEqual(viewModel.filters.map(\.title), ["All Friends", "India", "Exec", "Michigan"])
        XCTAssertEqual(viewModel.filteredPucks.count, 5)

        viewModel.selectedFilterID = "india"
        XCTAssertEqual(viewModel.filteredPucks.count, 3)
        viewModel.selectedFilterID = "michigan"
        XCTAssertEqual(viewModel.filteredPucks.count, 1)
    }

    @MainActor
    func testMapViewModelSurfacesRepositoryFailure() async throws {
        let container = AppDataContainer(seed: .standard())
        let viewModel = MapViewModel(
            friends: ThrowingFriendRepository(),
            groups: container.groups,
            sharing: container.sharing,
            pushes: container.pushes
        )
        await viewModel.load()
        if case .failed = viewModel.loadState {} else {
            XCTFail("expected .failed, got \(viewModel.loadState)")
        }
        XCTAssertTrue(viewModel.filteredPucks.isEmpty)
    }
}

extension DataLayerTests {

    // MARK: - StartPushViewModel

    @MainActor
    func testStartPushLoadsRecipientsAndSuggestions() async throws {
        let viewModel = StartPushViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()

        XCTAssertEqual(viewModel.groups.map(\.id), ["group_india", "group_exec", "group_michigan"])
        XCTAssertEqual(viewModel.groups.map(\.memberCount), [5, 3, 5])
        XCTAssertEqual(viewModel.friends.count, 10)

        XCTAssertEqual(viewModel.likelyFreeNow.map(\.id), [
            "friend_chitty", "friend_ishan", "friend_rohan", "friend_viplove"
        ])
        XCTAssertEqual(viewModel.mightBeInterested.map(\.id), [
            "friend_nitin", "friend_pranay", "friend_ram", "friend_ryan"
        ])
    }

    @MainActor
    func testStartPushRecipientSelectionBehavior() async throws {
        let viewModel = StartPushViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()

        viewModel.toggleRecipient("friend_chitty")
        viewModel.toggleRecipient("group_india")
        XCTAssertTrue(viewModel.isSelected("friend_chitty"))
        XCTAssertEqual(viewModel.selectedRecipients.count, 2)

        viewModel.toggleRecipient("friend_chitty")
        XCTAssertFalse(viewModel.isSelected("friend_chitty"))
        XCTAssertEqual(viewModel.selectedRecipients.count, 1)
    }
}

/// Proves the async-throws seam carries failures into LoadState.
struct ThrowingFriendRepository: FriendRepository {
    func friends() async throws -> [Person] { throw URLError(.badServerResponse) }
    func currentUser() async throws -> Person { throw URLError(.badServerResponse) }
    func presenceStatuses() async throws -> [PresenceStatus] { throw URLError(.badServerResponse) }
}
