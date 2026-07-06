//
//  FriendClusterPuck.swift
//  Push
//

import SwiftUI

struct FriendClusterPuck: View {
    let friends: [FriendPuckData]
    var size: CGFloat = FriendPuckLayout.defaultClusterSize

    private var leadAvailability: FriendAvailabilityState {
        friends
            .map(\.availability)
            .min { $0.priority < $1.priority } ?? .busy
    }

    private var sharedActivity: String {
        friends.first?.activityDisplayText ?? "Together"
    }

    private var sharedActivitySymbolName: String {
        friends.first?.activitySymbolName ?? "person.2.fill"
    }

    private var layoutKind: FriendClusterLayoutKind {
        FriendClusterLayoutKind(friendsCount: friends.count)
    }

    var body: some View {
        switch layoutKind {
        case .pair:
            PairHangoutPuck(
                friends: friends,
                size: size,
                sharedAvailability: leadAvailability,
                sharedActivity: sharedActivity,
                sharedActivitySymbolName: sharedActivitySymbolName
            )
        case .smallGroup:
            SmallGroupPuck(
                friends: friends,
                size: size,
                leadAvailability: leadAvailability,
                sharedActivity: sharedActivity,
                sharedActivitySymbolName: sharedActivitySymbolName
            )
        }
    }
}

private struct SmallGroupPuck: View {
    let friends: [FriendPuckData]
    let size: CGFloat
    let leadAvailability: FriendAvailabilityState
    let sharedActivity: String
    let sharedActivitySymbolName: String

    private var displayedFriends: [FriendPuckData] {
        Array(friends.prefix(SmallGroupLayout.visibleAvatarLimit))
    }

    var body: some View {
        avatarGroup
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(friends.count) friends, \(sharedActivity), \(leadAvailability.title)")
    }

    private var avatarGroup: some View {
        ZStack {
            ForEach(Array(displayedFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(leadAvailability.accentColor, lineWidth: SmallGroupLayout.avatarRingWidth)
                    }
                    .shadow(
                        color: leadAvailability.accentColor.opacity(SmallGroupLayout.avatarGlowOpacity),
                        radius: SmallGroupLayout.avatarGlowRadius,
                        y: SmallGroupLayout.avatarGlowYOffset
                    )
                    .offset(avatarOffset(for: index))
            }

            groupCount
                .offset(x: countXOffset, y: countYOffset)

            ActivityBadge(
                text: sharedActivity,
                symbolName: sharedActivitySymbolName,
                availability: leadAvailability
            )
            .offset(x: activityXOffset, y: activityYOffset)
        }
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

    private var avatarSize: CGFloat { size * SmallGroupLayout.avatarScale }
    private var countXOffset: CGFloat { avatarSize * SmallGroupLayout.countHorizontalAnchorScale }
    private var countYOffset: CGFloat { -avatarSize * SmallGroupLayout.countVerticalAnchorScale }
    private var activityXOffset: CGFloat { avatarSize * SmallGroupLayout.activityHorizontalAnchorScale }
    private var activityYOffset: CGFloat { avatarSize * SmallGroupLayout.activityVerticalAnchorScale }

    private func avatarOffset(for index: Int) -> CGSize {
        let offsets = SmallGroupLayout.avatarOffsets
        guard offsets.indices.contains(index) else { return .zero }
        return CGSize(
            width: offsets[index].width * avatarSize,
            height: offsets[index].height * avatarSize
        )
    }
}

private struct PairHangoutPuck: View {
    let friends: [FriendPuckData]
    let size: CGFloat
    let sharedAvailability: FriendAvailabilityState
    let sharedActivity: String
    let sharedActivitySymbolName: String

    private var pairFriends: [FriendPuckData] {
        Array(friends.prefix(PairHangoutLayout.friendCount))
    }

    var body: some View {
        avatarPair
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pairFriends.count) friends, \(sharedActivity), hanging out together")
    }

    private var avatarPair: some View {
        ZStack {
            ForEach(Array(pairFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(sharedAvailability.accentColor, lineWidth: PairHangoutLayout.avatarRingWidth)
                    }
                    .shadow(
                        color: sharedAvailability.accentColor.opacity(PairHangoutLayout.avatarGlowOpacity),
                        radius: PairHangoutLayout.avatarGlowRadius,
                        y: PairHangoutLayout.avatarGlowYOffset
                    )
                    .offset(x: avatarXOffset(for: index))
            }

            clusterCount
                .offset(x: countXOffset, y: countYOffset)

            ActivityBadge(
                text: sharedActivity,
                symbolName: sharedActivitySymbolName,
                availability: sharedAvailability
            )
            .offset(x: activityXOffset, y: activityYOffset)
        }
    }

    private var clusterCount: some View {
        Text("\(PairHangoutLayout.friendCount)")
            .font(.caption.weight(.black))
            .foregroundStyle(PuckColorTokens.avatarForeground)
            .frame(
                width: FriendPuckLayout.countBadgeSize,
                height: FriendPuckLayout.countBadgeSize
            )
            .background {
                Circle()
                    .fill(sharedAvailability.accentColor)
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(FriendPuckLayout.countStrokeOpacity), lineWidth: FriendPuckLayout.countStrokeWidth)
            }
    }

    private var avatarSize: CGFloat { size * PairHangoutLayout.avatarScale }
    private var pairCenterOffset: CGFloat { avatarSize * PairHangoutLayout.avatarCenterOffsetScale }
    private var countXOffset: CGFloat { pairCenterOffset + avatarSize * PairHangoutLayout.countHorizontalAnchorScale }
    private var countYOffset: CGFloat { -avatarSize * PairHangoutLayout.countVerticalAnchorScale }
    private var activityXOffset: CGFloat { pairCenterOffset + avatarSize * PairHangoutLayout.activityHorizontalAnchorScale }
    private var activityYOffset: CGFloat { avatarSize * PairHangoutLayout.activityVerticalAnchorScale }

    private func avatarXOffset(for index: Int) -> CGFloat {
        index == 0 ? -pairCenterOffset : pairCenterOffset
    }
}

private enum PairHangoutLayout {
    static let friendCount = 2
    static let avatarScale = 0.6
    static let avatarCenterOffsetScale = 0.28
    static let avatarRingWidth: CGFloat = 3
    static let avatarGlowOpacity = 0.24
    static let avatarGlowRadius: CGFloat = 12
    static let avatarGlowYOffset: CGFloat = 5
    static let countHorizontalAnchorScale = 0.42
    static let countVerticalAnchorScale = 0.4
    static let activityHorizontalAnchorScale = 0.15
    static let activityVerticalAnchorScale = 0.42
}

private enum SmallGroupLayout {
    static let visibleAvatarLimit = 3
    static let avatarScale = 0.5
    static let avatarRingWidth: CGFloat = 2.6
    static let avatarGlowOpacity = 0.22
    static let avatarGlowRadius: CGFloat = 10
    static let avatarGlowYOffset: CGFloat = 4
    static let countHorizontalAnchorScale = 0.75
    static let countVerticalAnchorScale = 0.6
    static let activityHorizontalAnchorScale = 0.3
    static let activityVerticalAnchorScale = 0.7
    static let avatarOffsets: [CGSize] = [
        CGSize(width: -0.28, height: -0.2),
        CGSize(width: 0.28, height: -0.2),
        CGSize(width: 0.0, height: 0.28)
    ]
}
