import UIKit
import XCTest
@testable import Push

@MainActor
final class CreatePostViewModelTests: XCTestCase {
    func testDefaultSegmentIsExistingMoments() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.selectedSegment, .existingMoments)
        XCTAssertEqual(viewModel.visibleChooserItems, viewModel.existingMoments)
    }

    func testSegmentSwitchFiltersVisibleRows() {
        let viewModel = makeViewModel()
        viewModel.selectedSegment = .pastPushes
        XCTAssertEqual(viewModel.visibleChooserItems, viewModel.pastPushes)
        XCTAssertFalse(viewModel.visibleChooserItems.contains { $0.showsMediaThumbnail })

        viewModel.selectedSegment = .existingMoments
        XCTAssertTrue(viewModel.visibleChooserItems.allSatisfy(\.showsMediaThumbnail))
    }

    func testFixturesSplitMomentsAndPastPushes() {
        XCTAssertFalse(CreatePostFixtures.existingMoments.isEmpty)
        XCTAssertFalse(CreatePostFixtures.pastPushes.isEmpty)
        for moment in CreatePostFixtures.existingMoments {
            XCTAssertTrue(moment.showsMediaThumbnail)
            XCTAssertNotNil(moment.contributionState)
            XCTAssertFalse(moment.mediaItems.isEmpty)
            XCTAssertFalse(moment.contributors.isEmpty)
            // Contributors are a subset of (or equal to) full membership.
            let memberIDs = Set(moment.participants.map(\.id))
            XCTAssertTrue(moment.contributors.allSatisfy { memberIDs.contains($0.id) })
        }
        for push in CreatePostFixtures.pastPushes {
            XCTAssertFalse(push.showsMediaThumbnail)
            XCTAssertEqual(push.style, .pastPush)
            XCTAssertTrue(push.mediaItems.isEmpty)
            XCTAssertTrue(push.contributors.isEmpty)
            XCTAssertFalse(push.participants.isEmpty)
        }
    }

    func testOnlyTwoContributionStates() {
        for moment in CreatePostFixtures.existingMoments {
            guard let state = moment.contributionState else {
                XCTFail("existing moment missing contribution state")
                continue
            }
            XCTAssertTrue(state == .openForAdds || state == .youContributed)
        }
        XCTAssertEqual(
            CreatePostContributionState.resolved(youContributed: true, openForAdds: true),
            .youContributed
        )
        XCTAssertEqual(
            CreatePostContributionState.resolved(youContributed: false, openForAdds: true),
            .openForAdds
        )
    }

    func testMediaCountUsesCombinedTotalAndPhotoIcon() {
        let sample = CreatePostFixtures.existingMoments[0]
        XCTAssertEqual(sample.mediaCount, sample.mediaItems.count)
        XCTAssertEqual(sample.mediaCountLabel, "\(sample.mediaItems.count)")
        XCTAssertEqual(sample.mediaSymbolName, "photo.on.rectangle")
        XCTAssertEqual(sample.carouselFirstMedia?.id, sample.mediaItems.first?.id)
    }

    func testStartFromScratchOpensFriendSelection() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()

        XCTAssertEqual(viewModel.screen, .selectFriends)
        XCTAssertEqual(viewModel.source, .scratch)
        XCTAssertTrue(viewModel.usesFriendSelection)
        XCTAssertTrue(viewModel.canContinueFromFriends)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.memberPersonRows.isEmpty)
        XCTAssertTrue(viewModel.selectedFriendIDs.isEmpty)
        XCTAssertFalse(viewModel.canSubmit)
    }

    func testContinueFromFriendsAllowsSoloAndAppliesSelection() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()

        // Solo is allowed — Next without picks.
        viewModel.continueFromFriends()
        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertTrue(viewModel.memberPersonRows.isEmpty)
        XCTAssertFalse(viewModel.canSubmit)

        viewModel.goBackToSelectFriends()
        XCTAssertEqual(viewModel.screen, .selectFriends)

        let friendID = CreatePostFixtures.selectableFriends[0].id
        viewModel.toggleFriend(friendID)
        XCTAssertTrue(viewModel.isFriendSelected(friendID))
        viewModel.continueFromFriends()
        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertEqual(viewModel.memberPersonRows.map(\.id), [friendID])
        XCTAssertEqual(viewModel.displayParticipants.map(\.id), [friendID])
    }

    func testFriendSearchFiltersList() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        let sampleName = CreatePostFixtures.selectableFriends[0].name
        viewModel.friendSearchText = sampleName
        XCTAssertEqual(viewModel.filteredFriends.count, 1)
        XCTAssertEqual(viewModel.filteredFriends.first?.name, sampleName)

        viewModel.friendSearchText = "zzz-no-match"
        XCTAssertTrue(viewModel.filteredFriends.isEmpty)
    }

    func testGoBackToSelectFriendsPreservesMediaDraft() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.seed(with: [draftPhoto()])
        viewModel.titleText = "Draft title"
        viewModel.goBackToSelectFriends()

        XCTAssertEqual(viewModel.screen, .selectFriends)
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.titleText, "Draft title")
    }

    func testOpenFeedMomentForEditPrefillsCompose() {
        let carousel = FeedMediaCarouselFixtures.threeBundlePhotos
        let viewModel = CreatePostViewModel.forEditingFeedMoment(carousel, timing: .immediate)

        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertTrue(viewModel.isEditingExistingMoment)
        XCTAssertEqual(viewModel.titleText, carousel.title)
        XCTAssertEqual(viewModel.locationText, carousel.locationTitle)
        XCTAssertEqual(
            viewModel.source,
            .existingMoment(id: CreatePostHistoryItem.feedMomentID(forCarouselID: carousel.id))
        )
        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertEqual(viewModel.primaryButtonTitle, CreatePostCopy.editPrimaryAction)
    }

    func testOpenFeedMomentForEditBuildsAdHocWhenNotInHubList() {
        // canAddYours fixture that is not always mirrored in CreatePostFixtures.existingMoments
        let carousel = FeedMediaCarouselFixtures.threeMixedAspectPhotos
        let hubIDs = Set(CreatePostFixtures.existingMoments.map(\.id))
        let momentID = CreatePostHistoryItem.feedMomentID(forCarouselID: carousel.id)
        // Prefer a carousel that isn't already an existing-moment fixture.
        if hubIDs.contains(momentID) {
            // Still valid if fixtures grow — open should succeed either path.
            let viewModel = CreatePostViewModel.forEditingFeedMoment(carousel, timing: .immediate)
            XCTAssertEqual(viewModel.screen, .compose)
            return
        }
        let viewModel = CreatePostViewModel.forEditingFeedMoment(carousel, timing: .immediate)
        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertEqual(viewModel.source, .existingMoment(id: momentID))
        XCTAssertEqual(viewModel.titleText, carousel.title)
    }

    func testOpenFriendEditorFromExistingMomentAllowsAddingPeople() {
        let sample = CreatePostFixtures.existingMoments[0]
        let viewModel = makeViewModel()
        viewModel.selectChooserItem(id: sample.id)

        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertTrue(viewModel.canEditPeople)
        let originalIDs = Set(viewModel.memberPersonRows.map(\.id))
        XCTAssertFalse(originalIDs.isEmpty)

        viewModel.openFriendEditor()
        XCTAssertEqual(viewModel.screen, .selectFriends)
        XCTAssertTrue(viewModel.isEditingPeopleFromCompose)
        XCTAssertEqual(viewModel.friendPickerPrimaryTitle, CreatePostCopy.selectFriendsDone)
        XCTAssertEqual(viewModel.selectedFriendIDs, originalIDs)

        let extra = CreatePostFixtures.selectableFriends.first {
            !originalIDs.contains($0.id)
        }
        XCTAssertNotNil(extra)
        if let extra {
            viewModel.toggleFriend(extra.id)
            viewModel.continueFromFriends()
            XCTAssertEqual(viewModel.screen, .compose)
            XCTAssertTrue(viewModel.memberPersonRows.map(\.id).contains(extra.id))
            XCTAssertTrue(originalIDs.isSubset(of: Set(viewModel.memberPersonRows.map(\.id))))
        }
    }

    func testCancelFriendEditorRestoresSelection() {
        let sample = CreatePostFixtures.existingMoments[0]
        let viewModel = makeViewModel()
        viewModel.selectChooserItem(id: sample.id)
        let originalIDs = Set(viewModel.memberPersonRows.map(\.id))

        viewModel.openFriendEditor()
        if let first = originalIDs.first {
            viewModel.toggleFriend(first) // deselect someone
        }
        viewModel.cancelFriendEditor()

        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertEqual(Set(viewModel.memberPersonRows.map(\.id)), originalIDs)
        XCTAssertEqual(viewModel.selectedFriendIDs, originalIDs)
    }

    func testSelectExistingMomentPrefillsComposeWithAllMembers() {
        let sample = CreatePostFixtures.existingMoments[0]
        let viewModel = makeViewModel()
        viewModel.selectChooserItem(id: sample.id)

        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertEqual(viewModel.source, .existingMoment(id: sample.id))
        XCTAssertEqual(viewModel.selectedHistoryID, sample.id)
        XCTAssertEqual(viewModel.titleText, sample.title)
        XCTAssertFalse(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.canSubmit)
        XCTAssertEqual(viewModel.composeTitle, CreatePostCopy.composeEditTitle)
        XCTAssertTrue(viewModel.isEditingExistingMoment)
        XCTAssertEqual(viewModel.primaryButtonTitle, CreatePostCopy.editPrimaryAction)
        // With section lists full Push membership, not only contributors.
        XCTAssertEqual(viewModel.memberPersonRows.count, sample.participants.count)
        XCTAssertEqual(
            viewModel.memberPersonRows.map(\.id),
            sample.participants.map(\.id)
        )
        XCTAssertGreaterThan(sample.participants.count, sample.contributors.count)
    }

    func testPrimaryButtonTitleForCreatePaths() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        XCTAssertFalse(viewModel.isEditingExistingMoment)
        XCTAssertEqual(viewModel.primaryButtonTitle, CreatePostCopy.primaryAction)

        let past = CreatePostFixtures.pastPushes[0]
        viewModel.goBackToHub()
        viewModel.selectChooserItem(id: past.id)
        XCTAssertFalse(viewModel.isEditingExistingMoment)
        XCTAssertEqual(viewModel.primaryButtonTitle, CreatePostCopy.primaryAction)
    }

    func testSelectPastPushOpensComposeWithoutMedia() {
        let sample = CreatePostFixtures.pastPushes[0]
        let viewModel = makeViewModel()
        viewModel.selectChooserItem(id: sample.id)

        XCTAssertEqual(viewModel.screen, .compose)
        XCTAssertEqual(viewModel.source, .pastPush(id: sample.id))
        XCTAssertEqual(viewModel.titleText, sample.title)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertFalse(viewModel.canSubmit)
        XCTAssertEqual(viewModel.memberPersonRows.count, sample.participants.count)
    }

    func testSelectUnknownChooserIsNoOp() {
        let viewModel = makeViewModel()
        viewModel.selectChooserItem(id: "missing-id")
        XCTAssertEqual(viewModel.screen, .hub)
        XCTAssertNil(viewModel.selectedHistoryID)
    }

    func testGoBackToHubResetsDraft() {
        let sample = CreatePostFixtures.existingMoments[0]
        let viewModel = makeViewModel()
        viewModel.selectChooserItem(id: sample.id)
        viewModel.goBackToHub()

        XCTAssertEqual(viewModel.screen, .hub)
        XCTAssertEqual(viewModel.source, .scratch)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertTrue(viewModel.memberPersonRows.isEmpty)
        XCTAssertNil(viewModel.selectedHistoryID)
    }

    func testTitleAndLocationClampToMaxLength() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        let long = String(repeating: "a", count: CreatePostLayout.titleMaxLength + 20)
        viewModel.titleText = long
        viewModel.locationText = long
        XCTAssertEqual(viewModel.titleText.count, CreatePostLayout.titleMaxLength)
        XCTAssertEqual(viewModel.locationText.count, CreatePostLayout.locationMaxLength)
    }

    func testSeedRespectsMaxSelection() {
        let viewModel = makeViewModel(maxSelection: 2)
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        viewModel.seed(with: [draftPhoto(), draftPhoto(), draftPhoto()])
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertFalse(viewModel.canAddMore)
    }

    func testSelectAndRemoveClampFocusedIndex() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        let a = draftPhoto()
        let b = draftPhoto()
        let c = draftPhoto()
        viewModel.seed(with: [a, b, c])

        viewModel.selectItem(at: 2)
        XCTAssertEqual(viewModel.focusedItem?.id, c.id)
        viewModel.removeFocusedItem()
        XCTAssertEqual(viewModel.items.count, 2)
        viewModel.removeFocusedItem()
        viewModel.removeFocusedItem()
        XCTAssertTrue(viewModel.items.isEmpty)
    }

    func testMoveMediaReordersAndPreservesFocus() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        let a = draftPhoto()
        let b = draftPhoto()
        let c = draftPhoto()
        viewModel.seed(with: [a, b, c])
        viewModel.selectItem(at: 2) // focus C

        // Move C (index 2) to front — becomes feed thumbnail (index 0).
        viewModel.moveMedia(from: 2, to: 0)
        XCTAssertEqual(viewModel.items.map(\.id), [c.id, a.id, b.id])
        XCTAssertEqual(viewModel.focusedItem?.id, c.id)
        XCTAssertEqual(viewModel.focusedIndex, 0)

        // Move cover C to end.
        viewModel.moveMedia(from: 0, to: 2)
        XCTAssertEqual(viewModel.items.map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual(viewModel.focusedItem?.id, c.id)
        XCTAssertEqual(viewModel.focusedIndex, 2)
    }

    func testMoveMediaNoOpsOnInvalidIndexes() {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        let a = draftPhoto()
        let b = draftPhoto()
        viewModel.seed(with: [a, b])
        viewModel.moveMedia(from: 0, to: 0)
        viewModel.moveMedia(from: 5, to: 0)
        XCTAssertEqual(viewModel.items.map(\.id), [a.id, b.id])
    }

    func testSubmitRequiresMediaAndSucceedsLocally() async {
        let viewModel = makeViewModel()
        viewModel.startFromScratch()
        viewModel.continueFromFriends()
        await viewModel.submit()
        XCTAssertEqual(viewModel.phase, .composing)

        viewModel.seed(with: [draftPhoto()])
        await viewModel.submit()
        XCTAssertEqual(viewModel.phase, .success)
    }

    func testHasRenderableMediaIgnoresMissingSources() {
        let item = CreatePostHistoryItem(
            id: "x",
            title: "T",
            dateLabel: "Mon",
            locationTitle: "Here",
            participants: [],
            contributors: [],
            mediaItems: [
                FeedMediaItem(id: "m", kind: .photo, source: .missing),
            ],
            style: .existingMoment(.openForAdds)
        )
        // First item is missing; no renderable fallback → no thumbnail media.
        XCTAssertNil(item.carouselThumbnailMedia)
        XCTAssertEqual(item.mediaCountLabel, "1")
    }

    // MARK: - Helpers

    private func makeViewModel(maxSelection: Int = 8) -> CreatePostViewModel {
        CreatePostViewModel(timing: .immediate, maxSelection: maxSelection)
    }

    private func draftPhoto() -> AddYoursDraftItem {
        AddYoursDraftItem(kind: .photo, previewImage: UIImage(systemName: "photo"))
    }
}
