// Push/PlansHistoryView.swift
// Month History list + read-only detail for completed Pushes.
import SwiftUI

struct PlansHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushLayout) private var layout
    @ObservedObject var viewModel: PlansViewModel

    var body: some View {
        ZStack {
            FriendsBackground()
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, PlansLayout.horizontalPadding(layout))
                    .padding(.top, PlansLayout.headerTopPadding)
                    .padding(.bottom, PlansLayout.moduleTitleCardSpacing)

                if viewModel.historyItems.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("History")
                .font(.title2.weight(.bold))
                .foregroundStyle(PushControlColors.textEspresso)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: PlansHistoryLayout.closeIconSize, weight: .semibold))
                    .foregroundStyle(PushControlColors.textSecondary)
                    .frame(
                        width: PlansHistoryLayout.closeTapSize,
                        height: PlansHistoryLayout.closeTapSize
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close history")
        }
    }

    private var list: some View {
        ScrollView {
            // Same list rhythm as Friends (`FriendsLayout.listSpacing` + page padding).
            // Rows are display-only for now — no detail modal on tap.
            LazyVStack(spacing: FriendsLayout.listSpacing) {
                ForEach(viewModel.historyItems) { item in
                    HistoryListRow(item: item)
                }
            }
            .padding(.horizontal, FriendsLayout.horizontalPadding(layout))
            .padding(.bottom, PlansLayout.startPlanButtonBottomPadding(layout))
        }
    }

    private var emptyState: some View {
        VStack(spacing: PlansHistoryLayout.emptySpacing) {
            Spacer()
            Text("No completed Pushes this month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PushControlColors.textSecondary)
                .multilineTextAlignment(.center)
            Text("When a Push finishes, it shows up here.")
                .font(.footnote)
                .foregroundStyle(PushControlColors.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, PlansLayout.horizontalPadding(layout))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row
//
// Mirrors `FriendRowCard` chrome: warm ivory `.friendsCard`, Friends padding /
// corner radius / row spacing — history content only differs.

private struct HistoryListRow: View {
    @Environment(\.pushLayout) private var layout
    let item: HistoryItemData

    var body: some View {
        HStack(alignment: .center, spacing: FriendsLayout.rowSpacing(layout)) {
            HistoryListPuck(people: item.participants, avatarSize: FriendsLayout.rowAvatarSize(layout))
            VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(2)
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
                if !item.didHappen {
                    Text("Almost happened")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(PushControlColors.textTertiary)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .friendsCard(cornerRadius: FriendsLayout.cardCornerRadius)
    }

    private var metaLine: String {
        PlansMetadata.joined([dayLabel, item.timeRange, item.locationHint])
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: item.date)
    }
}

// MARK: - Puck (Friends row avatar size; no live availability chrome)

private struct HistoryListPuck: View {
    let people: [HangoutPerson]
    let avatarSize: CGFloat

    private var overlap: CGFloat { avatarSize * PlansHistoryLayout.puckOverlapScale }

    var body: some View {
        let shown = Array(people.prefix(PlansHistoryLayout.puckMaxFaces))
        ZStack {
            if shown.isEmpty {
                Circle()
                    .fill(FriendsColor.cardCream)
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(
                                PushColorPalette.Accent.walnut.opacity(FriendsColor.neutralRingOpacity),
                                lineWidth: FriendsLayout.rowRingWidth
                            )
                    }
            } else {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, person in
                    ProfilePhotoAvatar(
                        imageAssetName: person.imageAssetName,
                        fallbackInitials: person.initials
                    )
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(
                                Color.white.opacity(FriendsColor.ringOpacity),
                                lineWidth: FriendsLayout.rowRingWidth
                            )
                    }
                    .offset(x: CGFloat(index) * overlap)
                }
            }
        }
        .frame(
            width: avatarSize + CGFloat(max(shown.count - 1, 0)) * overlap,
            height: avatarSize,
            alignment: .leading
        )
    }
}

private enum PlansHistoryLayout {
    static let closeIconSize: CGFloat = 14
    static let closeTapSize: CGFloat = 32
    static let emptySpacing: CGFloat = 8
    static let puckOverlapScale: CGFloat = 0.38
    static let puckMaxFaces = 3
}
