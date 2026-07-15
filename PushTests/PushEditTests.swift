//
//  PushEditTests.swift
//  PushTests
//

import XCTest
@testable import Push

@MainActor
final class PushEditTests: XCTestCase {

    func testEditContextPrefillsVisibleCardDetailsImmediately() {
        let plan = PlanData(
            id: "gym-later",
            title: "Gym later",
            group: "Exec",
            timeSignal: "~7:45 PM",
            socialProof: "4 going",
            locationHint: "Crunch Fitness",
            status: .joined,
            isOwner: true,
            participants: [
                HangoutPerson(id: "chitty", name: "Chitty", imageAssetName: "", initials: "CH"),
                HangoutPerson(id: "ishan", name: "Ishan", imageAssetName: "", initials: "IS")
            ],
            note: "Bring the guest pass"
        )

        let vm = StartPushViewModel(container: AppDataContainer(seed: .standard()), context: .edit(plan: plan))

        XCTAssertEqual(vm.step, StartPushStep.recipients)
        XCTAssertEqual(vm.selectedRecipientIDs, ["friend_chitty", "friend_ishan"])
        XCTAssertEqual(vm.pushText, "Gym later")
        XCTAssertEqual(vm.location, "Crunch Fitness")
        XCTAssertEqual(vm.notes, "Bring the guest pass")
    }

    func testUpdatePushEditsExistingPlanAndResponses() async throws {
        let container = AppDataContainer(seed: .standard())
        let beforeCount = try await container.pushes.activePlans().count
        let beforeRevision = container.storeRevision
        let startsAt = try XCTUnwrap(Calendar.current.date(from: DateComponents(
            year: 2026, month: 7, day: 10, hour: 18
        )))
        let draft = PushDraft(
            title: "Lift then dinner",
            recipientIDs: ["friend_chitty", "friend_ishan"],
            startsAt: startsAt,
            locationText: "Chelsea Piers",
            notes: "Bring wraps",
            creatorID: container.currentUserID
        )

        try await container.pushes.updatePush(planID: "gym-later", with: draft)

        let plans = try await container.pushes.activePlans()
        let plan = try XCTUnwrap(plans.first { $0.id == "gym-later" })
        XCTAssertEqual(plans.count, beforeCount)
        XCTAssertEqual(plan.title, "Lift then dinner")
        XCTAssertNil(plan.groupID)
        XCTAssertEqual(plan.audience, .inviteesOnly)
        XCTAssertEqual(plan.locationText, "Chelsea Piers")
        XCTAssertEqual(plan.note, "Bring wraps")
        XCTAssertEqual(container.storeRevision, beforeRevision + 1)

        let responses = try await container.pushes.responses().filter { $0.pushID == "gym-later" }
        XCTAssertEqual(Set(responses.map(\.personID)), ["manav", "chitty", "ishan"])
        XCTAssertEqual(responses.first { $0.personID == "chitty" }?.response, .in)
        XCTAssertEqual(responses.first { $0.personID == "manav" }?.response, .in)
    }

    func testStartPushViewModelEditModePrefillsAndUpdatesPush() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = StartPushViewModel(container: container, context: .edit(planID: "gym-later"))
        await vm.load()

        XCTAssertEqual(vm.step, StartPushStep.recipients)
        // "Gym later" is still addressed to the Exec group, so Manage preselects
        // the group itself rather than just the people who've already said in.
        XCTAssertEqual(vm.selectedRecipientIDs, ["group_exec"])
        XCTAssertEqual(vm.pushText, "Gym later")
        XCTAssertEqual(vm.location, "Crunch Fitness")

        vm.pushText = "Gym and smoothies"
        vm.location = "Equinox"
        vm.notes = "Meet by the front desk"
        await vm.submit()

        let plans = try await container.pushes.activePlans()
        let plan = try XCTUnwrap(plans.first { $0.id == "gym-later" })
        XCTAssertEqual(plan.title, "Gym and smoothies")
        XCTAssertEqual(plan.locationText, "Equinox")
        XCTAssertEqual(plan.note, "Meet by the front desk")
        XCTAssertFalse(plans.contains { $0.title == "Gym later" && $0.id != "gym-later" })
    }

    func testDrinksFridayManagePreselectsGroupDespiteExistingRSVPs() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = StartPushViewModel(container: container, context: .edit(planID: "drinks-friday"))
        await vm.load()

        XCTAssertEqual(vm.step, StartPushStep.recipients)
        // "Drinks Friday?" is still addressed to the Michigan group, so Manage
        // preselects the group rather than just rohan/ryan, who happen to have
        // already RSVP'd in. Regression coverage for the bug where Manage
        // derived its selection from `.in` responses and silently dropped the
        // group as soon as anyone accepted.
        XCTAssertEqual(vm.selectedRecipientIDs, ["group_michigan"])

        vm.pushText = "Drinks Saturday?"
        vm.location = "Rooftop"
        vm.notes = "No sneakers"
        await vm.submit()

        let plans = try await container.pushes.activePlans()
        let plan = try XCTUnwrap(plans.first { $0.id == "drinks-friday" })
        XCTAssertEqual(plan.title, "Drinks Saturday?")
        XCTAssertEqual(plan.groupID, "michigan")
        XCTAssertEqual(plan.locationText, "Rooftop")

        // Saving with the group still selected keeps every Michigan member
        // invited (existing RSVPs preserved, missing members added as pending).
        let responses = try await container.pushes.responses().filter { $0.pushID == "drinks-friday" }
        XCTAssertEqual(Set(responses.map(\.personID)), ["manav", "ram", "rohan", "ryan", "ohm", "pranay"])
        XCTAssertEqual(responses.first { $0.personID == "rohan" }?.response, .in)
        XCTAssertEqual(responses.first { $0.personID == "pranay" }?.response, .maybe)

        // Reopening Manage again still shows the group, not individuals —
        // the earlier fix must not have just been a one-time coincidence.
        let vmReopened = StartPushViewModel(container: container, context: .edit(planID: "drinks-friday"))
        await vmReopened.load()
        XCTAssertEqual(vmReopened.selectedRecipientIDs, ["group_michigan"])
    }

    func testDrinksFridayManageNarrowedToFriendsPersistsOnReopen() async throws {
        let container = AppDataContainer(seed: .standard())
        let vm = StartPushViewModel(container: container, context: .edit(planID: "drinks-friday"))
        await vm.load()

        // Deliberately narrow from the group down to just rohan and ryan.
        vm.selectedRecipientIDs = ["friend_rohan", "friend_ryan"]
        await vm.submit()

        let plans = try await container.pushes.activePlans()
        let plan = try XCTUnwrap(plans.first { $0.id == "drinks-friday" })
        XCTAssertNil(plan.groupID)

        // Reopening Manage must reflect that choice, not bounce back to the
        // group — this is the "correct data doesn't persist" half of the bug.
        let vmReopened = StartPushViewModel(container: container, context: .edit(planID: "drinks-friday"))
        await vmReopened.load()
        XCTAssertEqual(vmReopened.selectedRecipientIDs, ["friend_rohan", "friend_ryan"])
    }
}
