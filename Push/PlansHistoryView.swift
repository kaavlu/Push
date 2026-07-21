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
        .sheet(item: $viewModel.selectedHistoryItem) { item in
            HistoryDetailSheet(item: item)
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
            LazyVStack(spacing: FriendsLayout.listSpacing) {
                ForEach(viewModel.historyItems) { item in
                    Button {
                        viewModel.openHistoryItem(item)
                    } label: {
                        HistoryListRow(item: item)
                    }
                    .buttonStyle(.plain)
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
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

// MARK: - Detail

private struct HistoryDetailSheet: View {
    @Environment(\.pushLayout) private var layout
    let item: HistoryItemData

    private var dayHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: item.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PushControlColors.textEspresso)
                Text(dayHeader)
                    .font(.subheadline)
                    .foregroundStyle(PushControlColors.textSecondary)
                if !item.timeRange.isEmpty {
                    Text(item.timeRange)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PlansColor.metadata)
                }
            }
            .padding(.horizontal, PlansHistoryLayout.detailHorizontalPadding)
            .padding(.top, PlansHistoryLayout.detailTopPadding)
            .padding(.bottom, PlansHistoryLayout.detailHeaderBottom)

            VStack(alignment: .leading, spacing: PlansHistoryLayout.detailFieldSpacing) {
                if !item.groupName.isEmpty {
                    detailField(label: "Group", value: item.groupName)
                }
                if !item.locationHint.isEmpty {
                    detailField(label: "Location", value: item.locationHint)
                }
                detailField(
                    label: "Status",
                    value: item.didHappen ? "Completed" : "Almost happened"
                )
                if !item.participants.isEmpty {
                    Text("In")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PushControlColors.textTertiary)
                    HistoryListPuck(
                        people: item.participants,
                        avatarSize: FriendsLayout.rowAvatarSize(layout)
                    )
                    Text(participantNames)
                        .font(.subheadline)
                        .foregroundStyle(PushControlColors.textEspresso)
                }
            }
            .padding(.horizontal, PlansHistoryLayout.detailHorizontalPadding)

            Spacer(minLength: 0)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var participantNames: String {
        let names = item.participants.map(\.name)
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            return "\(names[0]), \(names[1]), and \(names.count - 2) others"
        }
    }

    private func detailField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textEspresso)
        }
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
    static let detailHorizontalPadding: CGFloat = 24
    static let detailTopPadding: CGFloat = 24
    static let detailHeaderBottom: CGFloat = 16
    static let detailFieldSpacing: CGFloat = 12
    static let puckOverlapScale: CGFloat = 0.38
    static let puckMaxFaces = 3
}
