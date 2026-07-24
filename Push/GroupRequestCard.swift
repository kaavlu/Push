//
//  GroupRequestCard.swift
//  Push
//
//  Alerts row for a pending group invite. Matches the friend-request card's
//  dimensions/chrome exactly (same `.friendsCard` shell, same accept/deny
//  capsules from AlertsStyle.swift) but swaps the circular friend avatar for
//  the rounded-rect group avatar treatment from `FriendGroupCard`.
//

import SwiftUI

struct GroupRequestCard: View {
    @Environment(\.pushLayout) private var layout
    let invite: GroupInvite
    let phase: AlertCardPhase?
    let isResolving: Bool
    let onAccept: () -> Void
    let onDeny: () -> Void

    private var isDenying: Bool { phase == .denying }

    var body: some View {
        HStack(spacing: FriendsLayout.groupIdentitySpacing(layout)) {
            avatar
            identity
                .layoutPriority(1)
            Spacer(minLength: 0)
            trailing
        }
        .padding(FriendsLayout.cardPadding(layout))
        .frame(maxWidth: .infinity, alignment: .leading)
        .pushSolidCreamCard(cornerRadius: FriendsLayout.cardCornerRadius)
        .opacity(isDenying ? 0 : 1)
        .scaleEffect(isDenying ? 0.96 : 1, anchor: .center)
        .animation(.easeOut(duration: AlertsLayout.denyCollapseDuration), value: isDenying)
        .animation(.easeInOut(duration: AlertsLayout.addedTransitionDuration), value: phase)
        .transition(
            .asymmetric(insertion: .opacity, removal: .opacity.combined(with: .move(edge: .top)))
        )
        .accessibilityElement(children: .contain)
    }

    private var avatar: some View {
        GroupListAvatar(
            imageAssetName: invite.imageAssetPath,
            fallbackInitials: groupInitials,
            size: FriendsLayout.groupAvatarSize(layout),
            cornerRadius: FriendsLayout.groupAvatarCornerRadius(layout)
        )
    }

    private var groupInitials: String {
        invite.groupName
            .split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.groupTextSpacing) {
            Text(invite.groupName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PushControlColors.textEspresso)
                .lineLimit(1)
                .minimumScaleFactor(FriendsLayout.minimumTextScale)

            Text(AlertsCopy.groupInviteSubtitle(inviterName: invite.inviterName))
                .font(.subheadline)
                .foregroundStyle(PushControlColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(FriendsLayout.minimumTextScale)

            Text(AlertsCopy.groupMemberCountLabel(invite.memberCount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PushControlColors.textTertiary)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if phase == .added {
            AlertAddedBadge()
        } else {
            HStack(spacing: AlertsLayout.actionSpacing) {
                AlertActionButton(
                    title: "Deny",
                    style: .deny,
                    disabled: isResolving,
                    accessibilityLabel: "Deny group invite to \(invite.groupName)",
                    action: onDeny
                )
                AlertActionButton(
                    title: "Accept",
                    style: .accept,
                    disabled: isResolving,
                    accessibilityLabel: "Accept group invite to \(invite.groupName)",
                    action: onAccept
                )
            }
        }
    }
}
