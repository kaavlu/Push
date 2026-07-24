// Push/Auth/AuthSocialButtons.swift
import SwiftUI

/// Google CTA shared by production welcome and sign-in.
/// Sign in with Apple is intentionally omitted so Personal Team builds
/// do not require the `com.apple.developer.applesignin` entitlement.
struct AuthSocialButtons: View {
    let isBusy: Bool
    let onGoogle: () -> Void

    var body: some View {
        OnboardingAuthButton(kind: .google, action: onGoogle)
            .disabled(isBusy)
            .opacity(isBusy ? AuthSocialButtonsLayout.disabledOpacity : 1)
            .animation(OnboardingLabMotion.fast, value: isBusy)
    }
}

/// Centered “or” rule matching the DEBUG onboarding lab sign-in layout.
struct AuthOrDivider: View {
    var body: some View {
        HStack(spacing: 14) {
            dividerLine
            Text("or")
                .font(OnboardingLabFont.text(13, .semibold))
                .foregroundStyle(OnboardingLabColor.textTertiary)
            dividerLine
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(OnboardingLabColor.walnut.opacity(AuthOrDividerLayout.lineOpacity))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

private enum AuthSocialButtonsLayout {
    static let disabledOpacity: Double = 0.5
}

private enum AuthOrDividerLayout {
    static let lineOpacity: Double = 0.16
}
