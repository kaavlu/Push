//
//  GroupsTests.swift
//  PushTests
//

import XCTest
@testable import Push

@MainActor
final class GroupsTests: XCTestCase {

    private func loadedViewModel() async -> GroupsViewModel {
        let viewModel = GroupsViewModel(container: AppDataContainer(seed: .standard()))
        await viewModel.load()
        return viewModel
    }

    func testGroupCardsDeriveFromCanonicalData() async throws {
        let viewModel = await loadedViewModel()
        XCTAssertEqual(viewModel.groups.map(\.name), ["India", "Exec", "Michigan"])
        XCTAssertEqual(viewModel.groups.map(\.memberCount), [5, 2, 5])
        XCTAssertEqual(viewModel.groups.map(\.status), [.activeNow, .activeNow, .planLive])
        XCTAssertEqual(viewModel.groups.map(\.activeNowCount), [2, 2, 5])
        XCTAssertEqual(viewModel.groups.map(\.nearbyCount), [2, 0, 0])
        XCTAssertEqual(viewModel.groups.map(\.planCount), [1, 2, 2])
        XCTAssertEqual(viewModel.groups.map(\.imageAssetName), [
            "assets/groups/India/chitty.png",
            "assets/groups/Exec/ram.png",
            "assets/groups/Michigan/ram.png"
        ])
    }

    func testGroupMembersResolveWithCanonicalAvailability() async throws {
        let viewModel = await loadedViewModel()
        let india = try XCTUnwrap(viewModel.groups.first)
        let members = viewModel.members(for: india)
        XCTAssertEqual(members.map(\.name), ["Chitty", "Nitin", "Ishan", "Viplove", "Roh"])
        XCTAssertEqual(members.first?.profileImageAssetName, "assets/friends/chitty.png")
        XCTAssertEqual(members.first { $0.id == "nitin" }?.availability, .maybeDown)
        XCTAssertEqual(members.first?.membershipID, "membership-india-chitty")
        XCTAssertTrue(members.first?.isOwner == true)
    }

    func testOwnerAndInviteHelpersUseCachedMemberships() async throws {
        let viewModel = await loadedViewModel()
        // Seed current user is not in India (chitty owns it).
        XCTAssertFalse(viewModel.isCurrentUserOwner(of: "india"))
        XCTAssertNil(viewModel.currentUserMembership(in: "india"))
        // Pending invites to exec/michigan are not active memberships.
        XCTAssertNil(viewModel.currentUserMembership(in: "exec"))
        // All non-self friends on India roster are occupied; candidates exclude them.
        let indiaOccupied = Set(try XCTUnwrap(viewModel.groups.first { $0.id == "india" }).memberIDs)
        let candidates = viewModel.inviteCandidates(for: "india")
        XCTAssertFalse(candidates.contains { indiaOccupied.contains($0.id) })
        XCTAssertFalse(candidates.isEmpty)
    }

    func testGroupsViewModelUpdatesSelectedGroupLocally() async throws {
        let viewModel = await loadedViewModel()
        let michigan = try XCTUnwrap(viewModel.groups.last)

        XCTAssertEqual(viewModel.selectedGroupID, "india")
        XCTAssertTrue(viewModel.isSelected(viewModel.groups[0]))

        viewModel.select(michigan)

        XCTAssertEqual(viewModel.selectedGroupID, "michigan")
        XCTAssertTrue(viewModel.isSelected(michigan))
        XCTAssertFalse(viewModel.isSelected(viewModel.groups[0]))
    }

    func testGroupsViewModelPresentsAndClosesDetailLocally() async throws {
        let viewModel = await loadedViewModel()
        let exec = try XCTUnwrap(viewModel.groups.first { $0.id == "exec" })

        XCTAssertNil(viewModel.presentedGroupID)

        viewModel.openDetail(for: exec)

        XCTAssertEqual(viewModel.presentedGroupID, "exec")
        XCTAssertEqual(viewModel.group(for: viewModel.presentedGroupID), exec)
        XCTAssertTrue(viewModel.isSelected(exec))

        viewModel.closeDetail()

        XCTAssertNil(viewModel.presentedGroupID)
    }

    func testSeamInitServesInjectedGroups() {
        let fixture = PushGroupData(
            id: "fixture", name: "Fixture", memberCount: 1, memberIDs: ["chitty"],
            status: .quiet, activeNowCount: 0, nearbyCount: 0, planCount: 0,
            imageAssetName: nil, fallbackSymbol: "F", fallbackInitials: "F"
        )
        let viewModel = GroupsViewModel(groups: [fixture])
        XCTAssertEqual(viewModel.groups, [fixture])
        XCTAssertEqual(viewModel.selectedGroupID, "fixture")
        XCTAssertTrue(viewModel.members(for: fixture).isEmpty)
    }
}
