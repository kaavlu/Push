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
        XCTAssertEqual(viewModel.groups.map(\.memberCount), [5, 3, 5])
        XCTAssertEqual(viewModel.groups.map(\.status), [.activeNow, .activeNow, .planLive])
        XCTAssertEqual(viewModel.groups.map(\.activeNowCount), [2, 3, 5])
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
