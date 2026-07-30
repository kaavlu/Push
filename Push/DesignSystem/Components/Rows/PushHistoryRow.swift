//
//  PushHistoryRow.swift
//  Push
//
//  DS-021 — history list row on solid cream foundation.
//

import SwiftUI

/// Completed-push history row for Plans History (display-only).
struct PushHistoryRow: View {
    @Environment(\.pushLayout) private var layout
    let item: HistoryItemData

    var body: some View {
        HStack(alignment: .center, spacing: FriendsLayout.rowSpacing(layout)) {
            PushHistoryAvatarStack(
                people: item.participants,
                avatarSize: FriendsLayout.rowAvatarSize(layout)
            )
            VStack(alignment: .leading, spacing: FriendsLayout.rowTextSpacing) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PushControlColors.textEspresso)
                    .lineLimit(2)
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(PushControlColors.textSecondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
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

/// Overlapping avatar stack at person-row size (no live availability chrome).
struct PushHistoryAvatarStack: View {
    let people: [HangoutPerson]
    let avatarSize: CGFloat

    private var overlap: CGFloat { avatarSize * PushHistoryRowMetrics.puckOverlapScale }

    var body: some View {
        let shown = Array(people.prefix(PushHistoryRowMetrics.puckMaxFaces))
        ZStack {
            if shown.isEmpty {
                Circle()
                    .fill(PushCreamTokens.solidCard)
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(
                                PushColorPalette.Accent.walnut.opacity(
                                    PushCreamTokens.neutralRingOpacity
                                ),
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
                                Color.white.opacity(PushCreamTokens.ringOpacity),
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

private enum PushHistoryRowMetrics {
    static let puckMaxFaces = 3
    static let puckOverlapScale: CGFloat = 0.38
}

/// Migration shim used by Plans History.
typealias HistoryListRow = PushHistoryRow
