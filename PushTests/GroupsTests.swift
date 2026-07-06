//
//  GroupsTests.swift
//  PushTests
//
//  Created by Manav Khanvilkar on 6/29/26.
//

import XCTest
@testable import Push

final class GroupsTests: XCTestCase {

    func testGroupMockDataExposesRequestedGroups() throws {
        let groups = GroupsMockData.groups

        XCTAssertEqual(groups.map(\.name), [
            "India",
            "Exec",
            "Michigan"
        ])
        XCTAssertEqual(groups.map(\.memberCount), [5, 3, 5])
        XCTAssertEqual(groups.map(\.status), [
            .activeNow,
            .nearby,
            .planLive
        ])
    }

    func testGroupMockDataExposesRequestedStats() throws {
        let groups = GroupsMockData.groups

        XCTAssertEqual(groups.map(\.activeNowCount), [3, 1, 2])
        XCTAssertEqual(groups.map(\.nearbyCount), [2, 1, 1])
        XCTAssertEqual(groups.map(\.planCount), [1, 0, 1])
        XCTAssertEqual(groups.map(\.imageAssetName), [
            "assets/groups/India/chitty.png",
            "assets/groups/Exec/ram.png",
            "assets/groups/Michigan/ram.png"
        ])
    }

    func testGroupMockDataUsesExtensibleMemberIDs() throws {
        let india = try XCTUnwrap(GroupsMockData.groups.first)

        XCTAssertEqual(india.id, "india")
        XCTAssertEqual(india.memberIDs, ["chitty", "nitin", "ishan", "viplove", "roh"])
    }

    func testGroupMembersResolveFromSeededFriendData() throws {
        let india = try XCTUnwrap(GroupsMockData.groups.first)
        let viewModel = GroupsViewModel()
        let members = viewModel.members(for: india)

        XCTAssertEqual(members.map(\.name), [
            "Chitty",
            "Nitin",
            "Ishan",
            "Viplove",
            "Roh"
        ])
        XCTAssertEqual(members.first?.profileImageAssetName, "assets/friends/chitty.png")
    }

    func testGroupsViewModelUpdatesSelectedGroupLocally() throws {
        let groups = GroupsMockData.groups
        let viewModel = GroupsViewModel(groups: groups)
        let michigan = try XCTUnwrap(groups.last)

        XCTAssertEqual(viewModel.selectedGroupID, "india")
        XCTAssertTrue(viewModel.isSelected(groups[0]))

        viewModel.select(michigan)

        XCTAssertEqual(viewModel.selectedGroupID, "michigan")
        XCTAssertTrue(viewModel.isSelected(michigan))
        XCTAssertFalse(viewModel.isSelected(groups[0]))
    }

    func testGroupsViewModelPresentsAndClosesDetailLocally() throws {
        let groups = GroupsMockData.groups
        let viewModel = GroupsViewModel(groups: groups)
        let exec = try XCTUnwrap(groups.first { $0.id == "exec" })

        XCTAssertNil(viewModel.presentedGroupID)

        viewModel.openDetail(for: exec)

        XCTAssertEqual(viewModel.presentedGroupID, "exec")
        XCTAssertEqual(viewModel.group(for: viewModel.presentedGroupID), exec)
        XCTAssertTrue(viewModel.isSelected(exec))

        viewModel.closeDetail()

        XCTAssertNil(viewModel.presentedGroupID)
    }
}
