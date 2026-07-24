//
//  PushGroupRow.swift
//  Push
//
//  DS-019 — group list row on solid cream foundation (separate from person row).
//

import SwiftUI

/// Compact group identity card for ivory group lists.
struct PushGroupRow: View {
    @Environment(\.pushLayout) private var layout
    let group: PushGroupData
    let members: [PushGroupMemberData]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: FriendsLayout.groupIdentitySpacing(layout)) {
                avatar
                identity
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
            .padding(FriendsLayout.cardPadding(layout))
            .frame(maxWidth: .infinity, alignment: .leading)
            .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(group.name)
        .accessibilityValue(summaryText)
    }

    private var avatar: some View {
        GroupListAvatar(
            imageAssetName: group.imageAssetName,
            fallbackInitials: group.fallbackInitials,
            size: FriendsLayout.groupAvatarSize(layout),
            cornerRadius: FriendsLayout.groupAvatarCornerRadius(layout)
        )
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.groupTextSpacing) {
            Text(group.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)

            Text(memberCountText)
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)

            Text(summaryText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    group.status == .quiet
                        ? PushControlColors.textTertiary
                        : PushControlColors.textPrimary
                )
                .lineLimit(1)
                .minimumScaleFactor(PushOpacityTokens.minimumTextScale)
        }
    }

    private var memberCountText: String {
        "\(group.memberCount) member\(group.memberCount == 1 ? "" : "s")"
    }

    private var summaryText: String {
        var parts: [String] = []
        if group.activeNowCount > 0 { parts.append("\(group.activeNowCount) active now") }
        if group.nearbyCount > 0 { parts.append("\(group.nearbyCount) nearby") }
        if group.planCount > 0 {
            parts.append("\(group.planCount) push\(group.planCount == 1 ? "" : "es")")
        }
        return parts.isEmpty ? group.status.title : parts.joined(separator: " · ")
    }
}

/// Migration shim — prefer `PushGroupRow`.
typealias FriendGroupCard = PushGroupRow

#if DEBUG
struct PushGroupRow_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            // Preview uses live list data in app; chrome-only smoke check.
            Text("PushGroupRow — see Friends Groups mode")
                .padding()
                .pushSolidCreamCard(cornerRadius: 20)
                .padding()
                .background(PushIvoryPageBackground())
        }
    }
}
#endif
