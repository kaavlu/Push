//
//  FriendPuck.swift
//  Push
//

import SwiftUI

struct FriendPuck: View {
    let friend: FriendPuckData
    var size: CGFloat = FriendPuckLayout.defaultSize

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatar
                .frame(width: size, height: size)
                .puckGlassBackground(cornerRadius: size / FriendPuckLayout.cornerDivisor)
                .availabilityPulse(
                    color: friend.availability.accentColor,
                    lineWidth: FriendPuckLayout.statusRingWidth
                )

            ActivityBadge(
                text: friend.activityDisplayText,
                symbolName: friend.activitySymbolName,
                availability: friend.availability
            )
            .offset(
                x: FriendPuckLayout.badgeOffset,
                y: FriendPuckLayout.badgeOffset
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(friend.name), \(friend.activityDisplayText), \(friend.availability.title), \(friend.venueStatusText)")
    }

    private var avatar: some View {
        ProfilePhotoAvatar(
            imageAssetName: friend.profileImageAssetName,
            fallbackInitials: friend.avatarPlaceholder
        )
    }
}

struct FriendGroupPuck: View {
    let friends: [FriendPuckData]
    var size: CGFloat = FriendPuckLayout.defaultSize

    private var leadAvailability: FriendAvailabilityState {
        friends
            .map(\.availability)
            .min { $0.priority < $1.priority } ?? .busy
    }

    private var groupPulseColor: Color {
        friends.contains { $0.isCurrentUser } ? PuckColorTokens.maybeDown : leadAvailability.accentColor
    }

    private var groupAvatarInitials: String {
        friends.first?.avatarPlaceholder ?? FriendGroupLayout.fallbackInitials
    }

    private var sharedActivity: String {
        friends.first?.activityDisplayText ?? "Together"
    }

    private var sharedActivitySymbolName: String {
        friends.first?.activitySymbolName ?? "person.3.fill"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ProfilePhotoAvatar(
                imageAssetName: friends.first?.profileImageAssetName,
                fallbackInitials: groupAvatarInitials
            )
                .frame(width: size, height: size)
                .puckGlassBackground(cornerRadius: size / FriendPuckLayout.cornerDivisor)
                .availabilityPulse(
                    ringColor: leadAvailability.accentColor,
                    pulseColor: groupPulseColor,
                    lineWidth: FriendPuckLayout.statusRingWidth
                )

            groupCount
                .offset(
                    x: FriendGroupLayout.countXOffset,
                    y: FriendGroupLayout.countYOffset
                )

            ActivityBadge(
                text: sharedActivity,
                symbolName: sharedActivitySymbolName,
                availability: leadAvailability
            )
            .offset(
                x: FriendPuckLayout.badgeOffset,
                y: FriendPuckLayout.badgeOffset
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(friends.count) person friend group, \(sharedActivity), \(leadAvailability.title)")
    }

    private var groupCount: some View {
        Text("\(friends.count)")
            .font(.caption.weight(.black))
            .foregroundStyle(PuckColorTokens.avatarForeground)
            .frame(
                width: FriendPuckLayout.countBadgeSize,
                height: FriendPuckLayout.countBadgeSize
            )
            .background {
                Circle()
                    .fill(leadAvailability.accentColor)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(FriendPuckLayout.countStrokeOpacity), lineWidth: FriendPuckLayout.countStrokeWidth)
            }
    }
}

private enum FriendGroupLayout {
    static let fallbackInitials = "FG"
    static let countXOffset: CGFloat = 6.8
    static let countYOffset: CGFloat = -70
}
