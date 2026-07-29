//
//  CreatePostHubView.swift
//  Push
//
//  Hub body: segment control, pinned Create from scratch (DS-091 action row),
//  then scrolling chooser list. Header lives in CreatePostFlowView.
//

import SwiftUI

struct CreatePostHubView: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: CreatePostViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pinned under the page header: segment → create (always visible).
            VStack(alignment: .leading, spacing: 0) {
                segmentControl
                createFromScratchRow
                    .padding(.top, CreatePostLayout.segmentToCreateSpacing)
            }
            .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))

            ScrollView(showsIndicators: false) {
                chooserList
                    .padding(.top, CreatePostLayout.createToListSpacing)
                    .padding(.horizontal, CreatePostLayout.horizontalPadding(layout))
                    .padding(.bottom, CreatePostLayout.bottomPadding(layout))
            }
        }
    }

    // MARK: - Create from scratch (DS-091)

    private var createFromScratchRow: some View {
        Button {
            viewModel.startFromScratch()
        } label: {
            PushCreateActionChooserRow(
                title: CreatePostCopy.createFromScratchTitle,
                subtitle: CreatePostCopy.createFromScratchSubtitle
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CreatePostCopy.createFromScratchTitle)
        .accessibilityHint(CreatePostCopy.createFromScratchSubtitle)
    }

    // MARK: - Segment

    private var segmentControl: some View {
        PushIvorySegmentedControl(
            items: viewModel.segmentItems,
            selectedID: Binding(
                get: { viewModel.selectedSegmentID },
                set: { viewModel.selectedSegmentID = $0 }
            )
        )
    }

    // MARK: - List

    @ViewBuilder
    private var chooserList: some View {
        if viewModel.visibleChooserItems.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: CreatePostLayout.chooserListSpacing) {
                ForEach(viewModel.visibleChooserItems) { item in
                    Button {
                        viewModel.selectChooserItem(id: item.id)
                    } label: {
                        CreatePostChooserRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(for: item))
                    .accessibilityHint(accessibilityHint(for: item))
                }
            }
        }
    }

    private var emptyState: some View {
        let isMoments = viewModel.selectedSegment == .existingMoments
        return EmptySurfaceView(
            title: isMoments
                ? CreatePostCopy.existingMomentsEmptyTitle
                : CreatePostCopy.pastPushesEmptyTitle,
            message: isMoments
                ? CreatePostCopy.existingMomentsEmptyMessage
                : CreatePostCopy.pastPushesEmptyMessage,
            systemImage: isMoments ? "photo.on.rectangle" : "bolt.fill",
            expandsVertically: false
        )
    }

    private func accessibilityLabel(for item: CreatePostHistoryItem) -> String {
        var parts = [item.title, item.dateLabel, item.locationTitle]
        if let contribution = item.contributionState {
            parts.append(contribution.chipTitle)
        }
        let people = FeedMediaParticipantCopy.namesLine(from: item.participants)
        if !people.isEmpty { parts.append(people) }
        if !item.mediaAccessibilityLabel.isEmpty {
            parts.append(item.mediaAccessibilityLabel)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func accessibilityHint(for item: CreatePostHistoryItem) -> String {
        switch item.style {
        case .existingMoment:
            return "Opens compose to edit this moment"
        case .pastPush:
            return "Starts a new moment from this Push"
        }
    }
}
