//
//  FriendPuck.swift
//  Push
//
//  Created by Manav Khanvilkar on 6/28/26.
//

import SwiftUI
import UIKit

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
                    color: leadAvailability.accentColor,
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

    private var avatarSize: CGFloat {
        size * SmallGroupLayout.avatarScale
    }

    private var countXOffset: CGFloat {
        avatarSize * SmallGroupLayout.countHorizontalAnchorScale
    }

    private var countYOffset: CGFloat {
        -avatarSize * SmallGroupLayout.countVerticalAnchorScale
    }

    private var activityXOffset: CGFloat {
        avatarSize * SmallGroupLayout.activityHorizontalAnchorScale
    }

    private var activityYOffset: CGFloat {
        avatarSize * SmallGroupLayout.activityVerticalAnchorScale
    }

    private func avatarOffset(for index: Int) -> CGSize {
        let offsets = SmallGroupLayout.avatarOffsets
        guard offsets.indices.contains(index) else {
            return .zero
        }

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

    private var avatarSize: CGFloat {
        size * PairHangoutLayout.avatarScale
    }

    private var pairCenterOffset: CGFloat {
        avatarSize * PairHangoutLayout.avatarCenterOffsetScale
    }

    private var countXOffset: CGFloat {
        pairCenterOffset + avatarSize * PairHangoutLayout.countHorizontalAnchorScale
    }

    private var countYOffset: CGFloat {
        -avatarSize * PairHangoutLayout.countVerticalAnchorScale
    }

    private var activityXOffset: CGFloat {
        pairCenterOffset + avatarSize * PairHangoutLayout.activityHorizontalAnchorScale
    }

    private var activityYOffset: CGFloat {
        avatarSize * PairHangoutLayout.activityVerticalAnchorScale
    }

    private func avatarXOffset(for index: Int) -> CGFloat {
        index == 0 ? -pairCenterOffset : pairCenterOffset
    }
}

struct ActivityBadge: View {
    let text: String
    let symbolName: String
    let availability: FriendAvailabilityState

    var body: some View {
        HStack(spacing: ActivityBadgeLayout.spacing) {
            Image(systemName: symbolName)
                .font(.system(size: ActivityBadgeLayout.iconSize, weight: .bold))

            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(PuckColorTokens.badgeForeground)
        .padding(.horizontal, ActivityBadgeLayout.horizontalPadding)
        .padding(.vertical, ActivityBadgeLayout.verticalPadding)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .background {
                    Capsule()
                        .fill(availability.accentColor.opacity(ActivityBadgeLayout.tintOpacity))
                }
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(ActivityBadgeLayout.strokeOpacity), lineWidth: ActivityBadgeLayout.strokeWidth)
        }
    }
}

struct AvatarStack: View {
    let friends: [FriendPuckData]
    let size: CGFloat

    private var displayedFriends: [FriendPuckData] {
        Array(friends.prefix(AvatarStackLayout.visibleAvatarLimit))
    }

    var body: some View {
        ZStack {
            ForEach(Array(displayedFriends.enumerated()), id: \.element.id) { index, friend in
                ProfilePhotoAvatar(
                    imageAssetName: friend.profileImageAssetName,
                    fallbackInitials: friend.avatarPlaceholder
                )
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(AvatarStackLayout.avatarStrokeOpacity), lineWidth: AvatarStackLayout.avatarStrokeWidth)
                    }
                    .offset(offset(for: index))
            }
        }
    }

    private var avatarSize: CGFloat {
        size * AvatarStackLayout.avatarScale
    }

    private func offset(for index: Int) -> CGSize {
        let offsets = AvatarStackLayout.offsets
        guard offsets.indices.contains(index) else {
            return .zero
        }

        return CGSize(
            width: offsets[index].width * size,
            height: offsets[index].height * size
        )
    }
}

private struct ProfilePhotoAvatar: View {
    let imageAssetName: String?
    let fallbackInitials: String

    var body: some View {
        Group {
            if let image = PushImageAssets.image(named: imageAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(fallbackInitials)
                    .font(.system(size: FriendPuckLayout.fallbackInitialsSize, weight: .bold, design: .rounded))
                    .foregroundStyle(PuckColorTokens.avatarForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        Circle()
                            .fill(PuckColorTokens.avatarGradientBase)
                    }
            }
        }
        .clipShape(Circle())
    }
}

private struct PulsingAvailabilityGlow: ViewModifier {
    let color: Color
    let lineWidth: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .stroke(color.opacity(FriendPuckLayout.pulseStrokeOpacity), lineWidth: lineWidth)
                    .scaleEffect(isPulsing ? FriendPuckLayout.pulseMaxScale : FriendPuckLayout.pulseMinScale)
                    .opacity(isPulsing ? FriendPuckLayout.pulseLowOpacity : FriendPuckLayout.pulseHighOpacity)
            }
            .overlay {
                Circle()
                    .stroke(color, lineWidth: lineWidth)
            }
            .shadow(
                color: color.opacity(FriendPuckLayout.statusGlowOpacity),
                radius: isPulsing ? FriendPuckLayout.statusGlowExpandedRadius : FriendPuckLayout.statusGlowRadius,
                y: FriendPuckLayout.statusGlowYOffset
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: FriendPuckLayout.pulseDuration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

private extension View {
    func availabilityPulse(color: Color, lineWidth: CGFloat) -> some View {
        modifier(PulsingAvailabilityGlow(color: color, lineWidth: lineWidth))
    }

    func puckGlassBackground(cornerRadius: CGFloat) -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(FriendPuckLayout.glassTintOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(FriendPuckLayout.glassStrokeOpacity), lineWidth: FriendPuckLayout.glassStrokeWidth)
        }
    }
}

private extension FriendAvailabilityState {
    var accentColor: Color {
        switch self {
        case .freeNow:
            return PuckColorTokens.freeNow
        case .freeSoon, .maybeDown:
            return PuckColorTokens.maybeDown
        case .busy:
            return PuckColorTokens.busy
        case .joinable:
            return PuckColorTokens.joinable
        case .driving:
            return PuckColorTokens.driving
        case .unavailable:
            return PuckColorTokens.unavailable
        }
    }

    var avatarGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(PuckColorTokens.avatarGradientHighOpacity),
                PuckColorTokens.avatarGradientBase
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private enum PuckColorTokens {
    static let avatarForeground = Color.white
    static let badgeForeground = Color.white
    static let avatarGradientBase = Color(red: 0.18, green: 0.15, blue: 0.22)
    static let avatarGradientHighOpacity = 0.88
    static let freeNow = Color(red: 0.43, green: 0.91, blue: 0.62)
    static let maybeDown = Color(red: 1.00, green: 0.78, blue: 0.24)
    static let busy = Color(red: 1.00, green: 0.50, blue: 0.25)
    static let joinable = Color(red: 0.25, green: 0.55, blue: 1.00)
    static let driving = Color(red: 0.22, green: 0.88, blue: 1.00)
    static let unavailable = Color(red: 0.55, green: 0.58, blue: 0.64)
}

private enum FriendPuckLayout {
    static let defaultSize: CGFloat = 82
    static let defaultClusterSize: CGFloat = 112
    static let cornerDivisor: CGFloat = 2
    static let initialsScale = 0.28
    static let fallbackInitialsSize: CGFloat = 22
    static let statusRingWidth: CGFloat = 3
    static let clusterRingWidth: CGFloat = 3.5
    static let statusGlowOpacity = 0.36
    static let statusGlowRadius: CGFloat = 14
    static let statusGlowExpandedRadius: CGFloat = 22
    static let clusterGlowRadius: CGFloat = 18
    static let statusGlowYOffset: CGFloat = 6
    static let pulseDuration = 2.4
    static let pulseMinScale = 1.02
    static let pulseMaxScale = 1.16
    static let pulseHighOpacity = 0.5
    static let pulseLowOpacity = 0.08
    static let pulseStrokeOpacity = 0.58
    static let badgeOffset: CGFloat = 6
    static let countOffset: CGFloat = 8
    static let countBadgeSize: CGFloat = 30
    static let countStrokeOpacity = 0.82
    static let countStrokeWidth: CGFloat = 1.4
    static let clusterBadgeInset: CGFloat = 36
    static let clusterBadgeOffset: CGFloat = 10
    static let glassTintOpacity = 0.16
    static let glassStrokeOpacity = 0.64
    static let glassStrokeWidth: CGFloat = 0.9
}

private enum FriendGroupLayout {
    static let fallbackInitials = "FG"
    static let countXOffset: CGFloat = 6.8
    static let countYOffset: CGFloat = -70
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

private enum ActivityBadgeLayout {
    static let spacing: CGFloat = 4
    static let iconSize: CGFloat = 9
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 5
    static let tintOpacity = 0.48
    static let strokeOpacity = 0.7
    static let strokeWidth: CGFloat = 0.8
}

private enum AvatarStackLayout {
    static let visibleAvatarLimit = 3
    static let avatarScale = 0.58
    static let initialsScale = 0.14
    static let avatarStrokeOpacity = 0.86
    static let avatarStrokeWidth: CGFloat = 1.4
    static let offsets: [CGSize] = [
        CGSize(width: -0.16, height: -0.11),
        CGSize(width: 0.18, height: -0.04),
        CGSize(width: 0.02, height: 0.2)
    ]
}
