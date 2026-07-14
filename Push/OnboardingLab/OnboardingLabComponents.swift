//
//  OnboardingLabComponents.swift
//  Push
//
//  Reusable building blocks shared across onboarding screens: the
//  espresso CTA pill, the numeric keypad, avatars with pulse rings,
//  the stylized mini map, status chips, and frosted cards.
//

import SwiftUI

// MARK: - Buttons

/// The primary espresso-gradient pill CTA used to advance each step.
struct OnboardingCTAButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(OnboardingLabFont.text(17, .bold))
            .foregroundStyle(OnboardingLabColor.ctaLabel)
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingLabMetric.ctaHeight)
            .background(PushOnboardingControlStyle.primaryGradient, in: Capsule())
            .shadow(
                color: OnboardingLabColor.ctaBottom.opacity(PushOnboardingControlStyle.primaryShadowOpacity),
                radius: PushOnboardingControlStyle.primaryShadowRadius,
                y: PushOnboardingControlStyle.primaryShadowYOffset
            )
        }
        .buttonStyle(PushPressStyle())
    }
}

/// Low-emphasis "Not now" / "Maybe later" text button.
struct OnboardingTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(OnboardingLabFont.text(15, .semibold))
                .foregroundStyle(OnboardingLabColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

/// Shrinks slightly while pressed, matching the web mock's `:active`.
// MARK: - Headings

/// Big rounded title + optional supporting line, left-aligned.
struct OnboardingHeader: View {
    let title: String
    var subtitle: String?
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(title)
                .font(OnboardingLabFont.rounded(30, .heavy))
                .foregroundStyle(OnboardingLabColor.espresso)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(OnboardingLabFont.text(16, .medium))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .multilineTextAlignment(alignment == .center ? .center : .leading)
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }
}

// MARK: - Avatars

/// Circular avatar loaded from a bundled asset path, with a colored
/// ring and an optional pulsing halo (used for "live" friends).
struct OnboardingAvatar: View {
    let assetName: String
    let size: CGFloat
    var ring: Color = .white
    var ringWidth: CGFloat = OnboardingLabMetric.avatarRingWidth
    var pulses = false

    var body: some View {
        ZStack {
            if pulses {
                OnboardingPulseRing(color: ring)
            }
            avatarImage
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(ring, lineWidth: ringWidth))
                .shadow(color: ring.opacity(0.4), radius: 9, y: 8)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let uiImage = PushImageAssets.image(named: assetName) {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else {
            Circle().fill(OnboardingLabColor.walnut.opacity(0.3))
        }
    }
}

/// Expanding, fading ring that loops — the "someone's live" pulse.
struct OnboardingPulseRing: View {
    let color: Color
    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 3)
            .scaleEffect(animating ? 1.55 : 1)
            .opacity(animating ? 0 : 0.55)
            .animation(.easeOut(duration: 2.6).repeatForever(autoreverses: false), value: animating)
            .onAppear { animating = true }
    }
}

// MARK: - Chips & cards

/// Rounded pill with a leading glyph and label; used for status +
/// the "you chose" privacy confirmation.
struct OnboardingStatusChip: View {
    let text: String
    var systemImage: String?
    var fill: Color
    var textColor: Color

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
            }
            Text(text)
                .font(OnboardingLabFont.text(13, .bold))
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(fill, in: Capsule())
    }
}

/// The signature frosted "liquid glass" container.
struct OnboardingGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = OnboardingLabMetric.cardCornerRadius
    @ViewBuilder var content: Content

    var body: some View {
        content
            .pushOnboardingGlassBackground(cornerRadius: cornerRadius)
    }
}

// MARK: - Mini map

/// Stylized map surface (warm gradient + faint diagonal "roads").
/// Callers overlay friend pucks on top.
struct OnboardingMiniMap<Overlay: View>: View {
    var cornerRadius: CGFloat = 26
    @ViewBuilder var overlay: Overlay

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [OnboardingLabColor.miniMapTop, OnboardingLabColor.miniMapBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            roads
            overlay
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
        )
    }

    private var roads: some View {
        GeometryReader { geo in
            ZStack {
                road(width: geo.size.width).rotationEffect(.degrees(-11)).offset(y: -geo.size.height * 0.16)
                road(width: geo.size.width).rotationEffect(.degrees(8)).offset(y: geo.size.height * 0.16)
            }
        }
    }

    private func road(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.45))
            .frame(width: width * 1.3, height: 11)
    }
}

// MARK: - Keypad

/// The 3×4 numeric keypad shared by the phone + verify screens.
struct OnboardingKeypad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 11), count: 3)

    var body: some View {
        keypadGrid
    }

    private var keypadGrid: some View {
        LazyVGrid(columns: columns, spacing: 11) {
            ForEach(1...9, id: \.self) { digit in
                key(String(digit)) { onDigit(digit) }
            }
            Color.clear.frame(height: 60)
            key("0") { onDigit(0) }
            Button(action: onDelete) {
                Image(systemName: "delete.left")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(OnboardingLabColor.walnut)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .buttonStyle(.plain)
        }
    }

    private func key(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(OnboardingLabFont.rounded(27, .bold))
                .foregroundStyle(OnboardingLabColor.espresso)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(OnboardingLabColor.keyFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: OnboardingLabColor.warmShadow.opacity(0.08), radius: 5, y: 4)
        }
        .buttonStyle(PushPressStyle())
    }
}
