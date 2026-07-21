//
//  FriendPuckStyle.swift
//  Push
//

import SwiftUI
import UIKit

struct ProfilePhotoAvatar: View {
    let imageAssetName: String?
    let fallbackInitials: String
    @State private var remoteImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Font must scale with the rendered size — callers range from
                    // 28pt push-card avatars to 82pt map pucks, and a fixed point
                    // size overflows/clips at the small end.
                    Text(fallbackInitials)
                        .font(.system(
                            size: proxy.size.width * FriendPuckLayout.initialsScale,
                            weight: .bold, design: .rounded
                        ))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(PuckColorTokens.avatarForeground)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            Circle()
                                .fill(PuckColorTokens.avatarGradientBase)
                        }
                }
            }
        }
        .clipShape(Circle())
        .task(id: imageAssetName) {
            remoteImage = nil
            remoteImage = await AvatarImageLoader.image(for: imageAssetName)
        }
    }

    private var displayImage: UIImage? {
        remoteImage ?? AvatarImageLoader.localImage(for: imageAssetName)
    }
}

private struct PulsingAvailabilityGlow: ViewModifier {
    let ringColor: Color
    let pulseColor: Color
    let lineWidth: CGFloat
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .stroke(pulseColor.opacity(FriendPuckLayout.pulseStrokeOpacity), lineWidth: lineWidth)
                    .scaleEffect(isPulsing ? FriendPuckLayout.pulseMaxScale : FriendPuckLayout.pulseMinScale)
                    .opacity(isPulsing ? FriendPuckLayout.pulseLowOpacity : FriendPuckLayout.pulseHighOpacity)
            }
            .overlay {
                Circle()
                    .stroke(ringColor, lineWidth: lineWidth)
            }
            .shadow(
                color: ringColor.opacity(FriendPuckLayout.statusGlowOpacity),
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

extension View {
    func availabilityPulse(color: Color, lineWidth: CGFloat) -> some View {
        modifier(PulsingAvailabilityGlow(ringColor: color, pulseColor: color, lineWidth: lineWidth))
    }

    func availabilityPulse(ringColor: Color, pulseColor: Color, lineWidth: CGFloat) -> some View {
        modifier(PulsingAvailabilityGlow(ringColor: ringColor, pulseColor: pulseColor, lineWidth: lineWidth))
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

extension FriendAvailabilityState {
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
        case .unavailable, .ghost:
            return PuckColorTokens.unavailable
        }
    }

    var chipFillColor: Color {
        switch self {
        case .freeNow:     return PuckColorTokens.freeNow.opacity(0.88)
        case .freeSoon:    return PuckColorTokens.maybeDown.opacity(0.82)
        case .maybeDown:   return PushColorPalette.Accent.sunbeam.opacity(0.90)
        case .busy:        return PuckColorTokens.busy.opacity(0.82)
        case .joinable:    return PuckColorTokens.joinable.opacity(0.88)
        case .driving:     return PuckColorTokens.driving.opacity(0.82)
        case .unavailable, .ghost: return PuckColorTokens.unavailable.opacity(0.55)
        }
    }

    var chipTextColor: Color {
        switch self {
        case .freeNow:     return Color(red: 0.04, green: 0.30, blue: 0.16)
        case .freeSoon:    return PushColorPalette.Accent.walnut
        case .maybeDown:   return PushColorPalette.Accent.walnut
        case .busy:        return Color(red: 0.52, green: 0.15, blue: 0.02)
        case .joinable:    return Color.white
        case .driving:     return Color(red: 0.02, green: 0.30, blue: 0.42)
        case .unavailable, .ghost: return Color(red: 0.22, green: 0.24, blue: 0.28)
        }
    }
}

enum PuckColorTokens {
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

enum FriendPuckLayout {
    static let defaultSize: CGFloat = 82
    static let defaultClusterSize: CGFloat = 112
    static let cornerDivisor: CGFloat = 2
    static let initialsScale = 0.28
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
