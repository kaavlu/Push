//
//  SelfPuckView.swift
//  Push
//

import SwiftUI

struct SelfPuckView: View {
    let data: SelfPuckData

    var body: some View {
        ZStack {
            halo

            VStack(spacing: SelfPuckLayout.badgeOverlap) {
                avatar
                    .frame(width: SelfPuckLayout.puckSize, height: SelfPuckLayout.puckSize)

                selfBadge
            }
        }
        .frame(width: SelfPuckLayout.frameWidth, height: SelfPuckLayout.frameHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You")
    }

    private var avatar: some View {
        ZStack {
            frostedPlate

            ProfilePhotoAvatar(
                imageAssetName: data.profileImageAssetName,
                fallbackInitials: data.avatarPlaceholder
            )
            .frame(width: SelfPuckLayout.photoSize, height: SelfPuckLayout.photoSize)
            .overlay {
                Circle()
                    .stroke(SelfPuckColor.champagne.opacity(SelfPuckLayout.innerRingOpacity), lineWidth: SelfPuckLayout.innerRingWidth)
                    .padding(SelfPuckLayout.innerRingInset)
            }
            .overlay {
                Circle()
                    .stroke(PushColorPalette.Accent.walnut.opacity(SelfPuckLayout.outerRingOpacity), lineWidth: SelfPuckLayout.outerRingWidth)
            }
        }
        .shadow(
            color: SelfPuckColor.champagne.opacity(SelfPuckLayout.champagneGlowOpacity),
            radius: SelfPuckLayout.champagneGlowRadius
        )
        .shadow(
            color: PushColorPalette.Accent.walnut.opacity(SelfPuckLayout.walnutShadowOpacity),
            radius: SelfPuckLayout.walnutShadowRadius,
            y: SelfPuckLayout.walnutShadowYOffset
        )
    }

    private var halo: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SelfPuckColor.creamGlow.opacity(SelfPuckLayout.haloCenterOpacity),
                            SelfPuckColor.champagne.opacity(SelfPuckLayout.haloMidOpacity),
                            .clear
                        ],
                        center: .center,
                        startRadius: SelfPuckLayout.haloStartRadius,
                        endRadius: SelfPuckLayout.haloEndRadius
                    )
                )
                .frame(width: SelfPuckLayout.haloSize, height: SelfPuckLayout.haloSize)
                .blur(radius: SelfPuckLayout.haloBlur)

            Circle()
                .stroke(SelfPuckColor.champagne.opacity(SelfPuckLayout.haloFeatherOpacity), lineWidth: SelfPuckLayout.haloFeatherWidth)
                .frame(width: SelfPuckLayout.haloFeatherSize, height: SelfPuckLayout.haloFeatherSize)
                .blur(radius: SelfPuckLayout.haloFeatherBlur)
        }
        .offset(y: SelfPuckLayout.haloYOffset)
    }

    private var frostedPlate: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .frame(width: SelfPuckLayout.puckSize, height: SelfPuckLayout.puckSize)
            .background {
                Circle()
                    .fill(SelfPuckColor.creamGlow.opacity(SelfPuckLayout.plateTintOpacity))
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(SelfPuckLayout.plateStrokeOpacity), lineWidth: SelfPuckLayout.plateStrokeWidth)
            }
    }

    private var selfBadge: some View {
        ActivityBadge(
            text: "You",
            symbolName: "person.fill",
            availability: .maybeDown,
            tintColor: SelfPuckColor.badgeTint,
            foregroundColor: .white
        )
            .shadow(
                color: PushColorPalette.Accent.walnut.opacity(SelfPuckLayout.badgeShadowOpacity),
                radius: SelfPuckLayout.badgeShadowRadius,
                y: SelfPuckLayout.badgeShadowYOffset
            )
    }
}

private enum SelfPuckColor {
    static let champagne = Color(red: 0.92, green: 0.78, blue: 0.48)
    static let creamGlow = Color(red: 1.00, green: 0.94, blue: 0.78)
    static let badgeTint = Color(red: 0.74, green: 0.58, blue: 0.34)
}

private enum SelfPuckLayout {
    static let frameWidth: CGFloat = 132
    static let frameHeight: CGFloat = 124
    static let puckSize: CGFloat = 58
    static let photoSize: CGFloat = 54
    static let haloSize: CGFloat = 104
    static let haloStartRadius: CGFloat = 6
    static let haloEndRadius: CGFloat = 52
    static let haloBlur: CGFloat = 15
    static let haloYOffset: CGFloat = -5
    static let haloCenterOpacity = 0.13
    static let haloMidOpacity = 0.062
    static let haloFeatherSize: CGFloat = 92
    static let haloFeatherWidth: CGFloat = 10
    static let haloFeatherOpacity = 0.048
    static let haloFeatherBlur: CGFloat = 18

    static let outerRingWidth: CGFloat = 1.7
    static let outerRingOpacity = 0.88
    static let innerRingWidth: CGFloat = 1
    static let innerRingInset: CGFloat = 3
    static let innerRingOpacity = 0.72
    static let champagneGlowOpacity = 0.18
    static let champagneGlowRadius: CGFloat = 8
    static let walnutShadowOpacity = 0.18
    static let walnutShadowRadius: CGFloat = 10
    static let walnutShadowYOffset: CGFloat = 5

    static let plateTintOpacity = 0.12
    static let plateStrokeOpacity = 0.44
    static let plateStrokeWidth: CGFloat = 0.8

    static let badgeOverlap: CGFloat = -10
    static let badgeShadowOpacity = 0.12
    static let badgeShadowRadius: CGFloat = 8
    static let badgeShadowYOffset: CGFloat = 4
}
