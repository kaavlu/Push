//
//  GroupLifecycleTests.swift
//  PushTests
//
//  Mock group lifecycle mutations via LocalGroupRepository / InMemoryDatabase.
//  Error contract: GroupRepositoryError (mirrors 0013 RPC exceptions).
//

import UIKit
import XCTest
@testable import Push

@MainActor
final class GroupLifecycleTests: XCTestCase {

    // MARK: - Rename

    func testRenameGroupUpdatesName() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Original", imageAssetPath: nil, inviteeIDs: []
        )

        try await container.groups.renameGroup(groupID: groupID, name: "  Renamed Crew  ")

        let group = try XCTUnwrap(container.database.groupsByID[groupID])
        XCTAssertEqual(group.name, "Renamed Crew")
    }

    /// Non-owners throw `GroupRepositoryError.notOwner` (same conceptual error as 0013).
    func testNonOwnerRenameThrowsOrNoopsPerMockContract() async throws {
        let container = AppDataContainer(seed: .standard())
        // Seed groups are owned by others; manav is only invited (exec/michigan) or absent (india).
        do {
            try await container.groups.renameGroup(groupID: "india", name: "Nope")
            XCTFail("expected notOwner")
        } catch let error as GroupRepositoryError {
            XCTAssertEqual(error, .notOwner)
        }
    }

    func testRenameEmptyNameThrowsInvalidName() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Keep", imageAssetPath: nil, inviteeIDs: []
        )
        do {
            try await container.groups.renameGroup(groupID: groupID, name: "   ")
            XCTFail("expected invalidName")
        } catch let error as GroupRepositoryError {
            XCTAssertEqual(error, .invalidName)
        }
        XCTAssertEqual(container.database.groupsByID[groupID]?.name, "Keep")
    }

    // MARK: - Invite / cancel

    /// Mock invite policy: non-self personIDs present in seed `peopleByID`; skips
    /// active/pending duplicates; does not require acceptedFriendIDs (more
    /// permissive than live RPC for discoverable seed people).
    func testInviteThenCancelAllowsReinvite() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Invite Lab", imageAssetPath: nil, inviteeIDs: []
        )

        try await container.groups.inviteToGroup(groupID: groupID, inviteeIDs: ["chitty"])
        let pending = container.database.memberships.first {
            $0.groupID == groupID && $0.personID == "chitty"
        }
        let membershipID = try XCTUnwrap(pending?.id)
        XCTAssertEqual(pending?.membershipStatus, .invited)

        try await container.groups.cancelGroupInvite(membershipID: membershipID)
        XCTAssertFalse(container.database.memberships.contains {
            $0.groupID == groupID && $0.personID == "chitty"
        })

        try await container.groups.inviteToGroup(groupID: groupID, inviteeIDs: ["chitty"])
        XCTAssertEqual(
            container.database.memberships.filter {
                $0.groupID == groupID && $0.personID == "chitty" && $0.membershipStatus == .invited
            }.count,
            1
        )
    }

    func testInviteSkipsActiveAndPendingDuplicates() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Dup Lab", imageAssetPath: nil, inviteeIDs: ["chitty"]
        )
        // chitty already pending from create; self + unknown + second chitty should not grow rows.
        let before = container.database.memberships.filter { $0.groupID == groupID }.count
        try await container.groups.inviteToGroup(
            groupID: groupID,
            inviteeIDs: ["chitty", container.currentUserID, "chitty", "not-a-person"]
        )
        let after = container.database.memberships.filter { $0.groupID == groupID }.count
        XCTAssertEqual(before, after)
        XCTAssertEqual(
            container.database.memberships.filter {
                $0.groupID == groupID && $0.personID == "chitty"
            }.count,
            1
        )
    }

    // MARK: - Remove / leave

    func testRemoveMemberDropsMembership() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await ownedGroupWithActiveMember(container, invitee: "chitty")

        try await container.groups.removeMember(groupID: groupID, personID: "chitty")

        XCTAssertFalse(container.database.memberships.contains {
            $0.groupID == groupID && $0.personID == "chitty"
        })
    }

    func testMemberCanLeave() async throws {
        let container = AppDataContainer(seed: .standard())
        // Accept seeded pending invite → active non-owner member of exec.
        let inviteID = "membership-exec-\(container.currentUserID)"
        try await container.alerts.acceptGroupInvite(id: inviteID)

        try await container.groups.leaveGroup(groupID: "exec")

        XCTAssertFalse(container.database.memberships.contains {
            $0.groupID == "exec" && $0.personID == container.currentUserID
        })
        XCTAssertNotNil(container.database.groupsByID["exec"])
    }

    func testOwnerLeaveWithOthersFails() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await ownedGroupWithActiveMember(container, invitee: "chitty")

        do {
            try await container.groups.leaveGroup(groupID: groupID)
            XCTFail("expected transferRequired")
        } catch let error as GroupRepositoryError {
            XCTAssertEqual(error, .transferRequired)
        }
        XCTAssertNotNil(container.database.groupsByID[groupID])
    }

    func testOwnerLeaveWhenSoleMemberDeletesGroup() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Solo", imageAssetPath: nil, inviteeIDs: []
        )

        try await container.groups.leaveGroup(groupID: groupID)

        XCTAssertNil(container.database.groupsByID[groupID])
        XCTAssertFalse(container.database.memberships.contains { $0.groupID == groupID })
        XCTAssertFalse(container.database.orderedGroups.contains { $0.id == groupID })
    }

    // MARK: - Transfer / delete

    func testTransferOwnershipIsAtomic() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await ownedGroupWithActiveMember(container, invitee: "chitty")
        let revisionBefore = container.database.revision

        try await container.groups.transferOwnership(groupID: groupID, newOwnerID: "chitty")

        let me = container.database.memberships.first {
            $0.groupID == groupID && $0.personID == container.currentUserID
        }
        let them = container.database.memberships.first {
            $0.groupID == groupID && $0.personID == "chitty"
        }
        XCTAssertEqual(me?.role, .member)
        XCTAssertEqual(them?.role, .owner)
        XCTAssertEqual(container.database.revision, revisionBefore + 1)
    }

    func testPendingCannotBecomeOwner() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Pending Owner", imageAssetPath: nil, inviteeIDs: ["chitty"]
        )

        do {
            try await container.groups.transferOwnership(groupID: groupID, newOwnerID: "chitty")
            XCTFail("expected invalidTarget")
        } catch let error as GroupRepositoryError {
            XCTAssertEqual(error, .invalidTarget)
        }
        let owner = container.database.memberships.first {
            $0.groupID == groupID && $0.role == .owner
        }
        XCTAssertEqual(owner?.personID, container.currentUserID)
    }

    func testDeleteGroupRemovesGroupAndMembershipsNullsPushGroupID() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Doomed", imageAssetPath: nil, inviteeIDs: ["chitty"]
        )
        let planID = try await container.pushes.createPush(
            PushDraft(
                title: "Hang",
                recipientIDs: ["group_\(groupID)"],
                startsAt: Date().addingTimeInterval(3600),
                locationText: "Park",
                notes: "",
                creatorID: container.currentUserID
            )
        )
        XCTAssertEqual(container.database.plansByID[planID]?.groupID, groupID)

        try await container.groups.deleteGroup(groupID: groupID)

        XCTAssertNil(container.database.groupsByID[groupID])
        XCTAssertFalse(container.database.memberships.contains { $0.groupID == groupID })
        XCTAssertNil(container.database.plansByID[planID]?.groupID)
        // Push row itself remains (FK SET NULL, not cascade delete).
        XCTAssertNotNil(container.database.plansByID[planID])
    }

    // MARK: - Photo

    func testUpdateAndRemoveGroupPhoto() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "Photo Lab", imageAssetPath: nil, inviteeIDs: []
        )
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 48, height: 48, color: .blue))
        )

        try await container.groups.updateGroupPhoto(groupID: groupID, jpegData: jpeg)
        let path = try XCTUnwrap(container.database.groupsByID[groupID]?.imageAssetPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        try await container.groups.removeGroupPhoto(groupID: groupID)
        XCTAssertNil(container.database.groupsByID[groupID]?.imageAssetPath)
        GroupPhotoFileStore.remove(groupID: groupID)
    }

    func testCreateGroupThenPhotoPersistsPath() async throws {
        let container = AppDataContainer(seed: .standard())
        let groupID = try await container.groups.createGroup(
            name: "With Photo", imageAssetPath: nil, inviteeIDs: []
        )
        let jpeg = try XCTUnwrap(
            ProfilePhotoProcessor.jpegData(from: makeSolidImage(width: 32, height: 32, color: .green))
        )

        try await container.groups.updateGroupPhoto(groupID: groupID, jpegData: jpeg)

        let groups = try await container.groups.groups()
        let group = try XCTUnwrap(groups.first { $0.id == groupID })
        let path = try XCTUnwrap(group.imageAssetPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertNotNil(UIImage(contentsOfFile: path))

        GroupPhotoFileStore.remove(groupID: groupID)
    }

    /// Add Group flow: create with nil path, then upload picked JPEG via `updateGroupPhoto`.
    func testAddGroupViewModelSubmitPersistsPickedPhoto() async throws {
        let container = AppDataContainer(seed: .standard())
        let friends = try await container.friends.friends()
        XCTAssertGreaterThanOrEqual(friends.count, 2)

        let viewModel = AddGroupViewModel(container: container)
        // Wait for friends load started in init.
        for _ in 0..<20 where viewModel.loadState.value == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        viewModel.groupName = "VM Photo Crew"
        viewModel.selectedFriendIDs = Set(friends.prefix(2).map(\.id))
        viewModel.pickedImage = makeSolidImage(width: 40, height: 40, color: .systemOrange)

        let submittedID = await viewModel.submit()
        let groupID = try XCTUnwrap(submittedID)
        XCTAssertNil(viewModel.actionError)

        let group = try XCTUnwrap(container.database.groupsByID[groupID])
        let path = try XCTUnwrap(group.imageAssetPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))

        GroupPhotoFileStore.remove(groupID: groupID)
    }

    // MARK: - GroupsViewModel mutations

    func testRemoveMemberFailureSetsActionError() async {
        let fixture = PushGroupData(
            id: "g1", name: "Crew", memberCount: 2, memberIDs: ["a", "b"],
            status: .quiet, activeNowCount: 0, nearbyCount: 0, planCount: 0,
            imageAssetName: nil, fallbackSymbol: "C", fallbackInitials: "C"
        )
        let viewModel = GroupsViewModel(
            groups: [fixture],
            groupsRepository: ThrowingGroupRepository()
        )

        await viewModel.removeMember(groupID: "g1", personID: "b")

        XCTAssertEqual(viewModel.actionError?.message, "Couldn't remove that member. Try again.")
        // Wait-for-success: list unchanged on failure.
        XCTAssertEqual(viewModel.groups.map(\.id), ["g1"])
    }

    func testLeaveGroupSuccessClosesDetail() async throws {
        let container = AppDataContainer(seed: .standard())
        let inviteID = "membership-exec-\(container.currentUserID)"
        try await container.alerts.acceptGroupInvite(id: inviteID)

        let viewModel = GroupsViewModel(container: container)
        await viewModel.load()
        let exec = try XCTUnwrap(viewModel.groups.first { $0.id == "exec" })
        viewModel.openDetail(for: exec)
        XCTAssertEqual(viewModel.presentedGroupID, "exec")

        await viewModel.leaveGroup(groupID: "exec")

        XCTAssertNil(viewModel.actionError)
        XCTAssertNil(viewModel.presentedGroupID)
        XCTAssertNil(viewModel.currentUserMembership(in: "exec"))
    }

    // MARK: - Helpers

    /// Creates a group owned by the current user with one active (accepted) member.
    private func ownedGroupWithActiveMember(
        _ container: AppDataContainer, invitee: Person.ID
    ) async throws -> FriendGroup.ID {
        let groupID = try await container.groups.createGroup(
            name: "Owned", imageAssetPath: nil, inviteeIDs: [invitee]
        )
        let membership = try XCTUnwrap(
            container.database.memberships.first {
                $0.groupID == groupID && $0.personID == invitee
            }
        )
        // resolveGroupInvite is membership-id based (invitee auth checked at live RPC).
        container.database.resolveGroupInvite(id: membership.id, accept: true)
        return groupID
    }

    private func makeSolidImage(width: CGFloat, height: CGFloat, color: UIColor) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// All group writes throw — mutation failure tests for `GroupsViewModel`.
private struct ThrowingGroupRepository: GroupRepository {
    enum Failure: Error { case expected }

    func groups() async throws -> [FriendGroup] { [] }
    func memberships() async throws -> [GroupMembership] { [] }
    func createGroup(
        name: String, imageAssetPath: String?, inviteeIDs: [Person.ID]
    ) async throws -> FriendGroup.ID { throw Failure.expected }
    func renameGroup(groupID: FriendGroup.ID, name: String) async throws {
        throw Failure.expected
    }
    func updateGroupPhoto(groupID: FriendGroup.ID, jpegData: Data) async throws {
        throw Failure.expected
    }
    func removeGroupPhoto(groupID: FriendGroup.ID) async throws { throw Failure.expected }
    func inviteToGroup(groupID: FriendGroup.ID, inviteeIDs: [Person.ID]) async throws {
        throw Failure.expected
    }
    func cancelGroupInvite(membershipID: GroupMembership.ID) async throws {
        throw Failure.expected
    }
    func removeMember(groupID: FriendGroup.ID, personID: Person.ID) async throws {
        throw Failure.expected
    }
    func leaveGroup(groupID: FriendGroup.ID) async throws { throw Failure.expected }
    func transferOwnership(groupID: FriendGroup.ID, newOwnerID: Person.ID) async throws {
        throw Failure.expected
    }
    func deleteGroup(groupID: FriendGroup.ID) async throws { throw Failure.expected }
}
