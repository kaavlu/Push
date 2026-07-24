//
//  OnboardingSignInScreen.swift
//  Push
//
//  Returning-user entry point: email/password plus Google.
//  Peer to the sign-up (welcome) screen; the two cross-link via
//  OnboardingAuthSwitchLink. Reuses the shared onboarding components,
//  colors, and typography so it reads as the same system.
//

#if DEBUG
import SwiftUI

struct OnboardingSignInScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Welcome back",
                subtitle: "Sign in to pick up right where you left off."
            )
            fields.padding(.top, 26)
            signInCTA.padding(.top, 22)
            orDivider.padding(.vertical, 20)
            socialButtons
            Spacer(minLength: 24)
            OnboardingAuthSwitchLink(
                prompt: "Don't have an account?",
                action: "Sign up"
            ) { model.goToSignUp() }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    // MARK: Credential fields

    private var fields: some View {
        VStack(spacing: 12) {
            OnboardingCredentialField(
                systemImage: "envelope.fill",
                placeholder: "Username or email",
                text: $model.email,
                isSecure: false
            )
            OnboardingCredentialField(
                systemImage: "lock.fill",
                placeholder: "Password",
                text: $model.password,
                isSecure: true
            )
        }
    }

    // MARK: Primary action

    private var signInCTA: some View {
        OnboardingCTAButton(title: "Sign in") {
            guard model.canSubmitSignIn else { return }
            model.completeSignIn()
        }
        .disabled(!model.canSubmitSignIn)
        .opacity(model.canSubmitSignIn ? 1 : 0.5)
        .animation(OnboardingLabMotion.fast, value: model.canSubmitSignIn)
    }

    // MARK: Divider

    private var orDivider: some View {
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
            .fill(OnboardingLabColor.walnut.opacity(0.16))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    // MARK: Social sign-in

    private var socialButtons: some View {
        OnboardingAuthButton(kind: .google) { model.completeSignIn() }
    }
}

// `OnboardingCredentialField` and `OnboardingAuthSwitchLink` now live in
// OnboardingAuthComponents.swift (promoted out of DEBUG so the production
// auth gate can reuse them).
#endif
