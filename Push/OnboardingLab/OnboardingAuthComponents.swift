//
//  OnboardingAuthComponents.swift
//  Push
//
//  Auth-surface building blocks shared by the DEBUG onboarding lab and
//  the production auth gate (Push/Auth/): the social/mobile CTA pill,
//  the sign-in ⇄ sign-up footer link, and the credential text field.
//  Promoted out of the lab (not DEBUG-gated) so AuthWelcomeView and
//  AuthSignInView render pixel-identical to the design lab. Split from
//  OnboardingLabComponents.swift to keep both files under the project's
//  400-line limit.
//

import SwiftUI

// MARK: - Social / mobile CTA

/// Sign-in button with the three brand-appropriate looks.
struct OnboardingAuthButton: View {
    enum Kind { case apple, google, mobile }
    let kind: Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: OnboardingAuthButtonLayout.iconTextSpacing) {
                icon
                    .frame(width: OnboardingAuthButtonLayout.iconFrameWidth)
                Text(title)
            }
            .font(OnboardingLabFont.text(17, .semibold))
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingLabMetric.ctaHeight)
            .background(fill, in: Capsule())
            .shadow(
                color: OnboardingLabColor.warmShadow.opacity(PushOnboardingControlStyle.secondaryShadowOpacity),
                radius: PushOnboardingControlStyle.secondaryShadowRadius,
                y: PushOnboardingControlStyle.secondaryShadowYOffset
            )
        }
        .buttonStyle(PushPressStyle())
    }

    private var title: String {
        switch kind {
        case .apple: return "Continue with Apple"
        case .google: return "Continue with Google"
        case .mobile: return "Use mobile number"
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .apple: Image(systemName: "apple.logo")
        case .google: googleLogo
        case .mobile: Image(systemName: "iphone")
        }
    }

    @ViewBuilder
    private var googleLogo: some View {
        if let image = PushImageAssets.image(named: OnboardingAuthButtonLayout.googleLogoAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: OnboardingAuthButtonLayout.googleLogoSize, height: OnboardingAuthButtonLayout.googleLogoSize)
        } else {
            Text("G")
                .font(OnboardingLabFont.rounded(18, .heavy))
        }
    }

    private var labelColor: Color {
        switch kind {
        case .apple: return .white
        case .google: return OnboardingLabColor.googleButtonText
        case .mobile: return OnboardingLabColor.walnut
        }
    }

    private var fill: Color {
        switch kind {
        case .apple: return OnboardingLabColor.appleButtonFill
        case .google: return .white
        case .mobile: return OnboardingLabColor.walnut.opacity(0.12)
        }
    }
}

private enum OnboardingAuthButtonLayout {
    static let iconTextSpacing: CGFloat = 10
    static let iconFrameWidth: CGFloat = 22
    static let googleLogoSize: CGFloat = 18
    static let googleLogoAssetName = "assets/onboarding/google-logo.png"
}

// MARK: - Sign-in ⇄ sign-up switch link

/// The "Already have an account? Sign in" / "Don't have an account?
/// Sign up" footer link shared by both entry screens.
struct OnboardingAuthSwitchLink: View {
    let prompt: String
    let action: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            (Text("\(prompt) ")
                .foregroundColor(OnboardingLabColor.textSecondary)
                + Text(action)
                .foregroundColor(OnboardingLabColor.walnut)
                .bold())
                .font(OnboardingLabFont.text(15, .medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Credential field

/// A single credential row: leading glyph + text or secure entry, styled
/// to match the phone/code fields (warm fill, rounded corners).
struct OnboardingCredentialField: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OnboardingLabColor.walnut)
                .frame(width: 22)
            entryField
        }
        .padding(.horizontal, 18)
        .frame(height: OnboardingLabMetric.fieldHeight)
        .background(
            OnboardingLabColor.fieldFill,
            in: RoundedRectangle(cornerRadius: OnboardingLabMetric.fieldCornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private var entryField: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
            }
        }
        .font(OnboardingLabFont.text(17, .medium))
        .foregroundStyle(OnboardingLabColor.espresso)
        .tint(OnboardingLabColor.walnut)
    }
}
