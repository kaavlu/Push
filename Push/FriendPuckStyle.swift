//
//  FriendPuckStyle.swift
//  Push
//
//  Map puck pulse rings + layout. Person avatar and availability colors live
//  in DesignSystem (PushPersonAvatar, PushAvailabilityTokens).
//

import SwiftUI

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

    /// Prefer `pushPuckGlass` (DS-012).
    func puckGlassBackground(cornerRadius: CGFloat) -> some View {
        pushPuckGlass(cornerRadius: cornerRadius)
    }
}

// Availability colors → PushAvailabilityTokens (PuckColorTokens typealias).

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
    /// Prefer `PushPuckGlassTokens`.
    static let glassTintOpacity = PushPuckGlassTokens.tintOpacity
    static let glassStrokeOpacity = PushPuckGlassTokens.strokeOpacity
    static let glassStrokeWidth = PushPuckGlassTokens.strokeWidth
}
