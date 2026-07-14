// Push/Auth/AuthSignInView.swift
import SwiftUI

/// Production returning-user sign-in screen: the same layout as the DEBUG
/// onboarding lab's `OnboardingSignInScreen`, but backed by real Supabase
/// auth via `AuthViewModel.submitPrimary()`. Apple/Google are shown for
/// visual parity with the design but aren't wired to real auth yet — they
/// surface "coming soon" rather than silently doing nothing.
struct AuthSignInView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Welcome back",
                subtitle: "Sign in to pick up right where you left off."
            )
            fields.padding(.top, 26)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            signInCTA.padding(.top, 22)
            orDivider.padding(.vertical, 20)
            socialButtons
            Spacer(minLength: 24)
            OnboardingAuthSwitchLink(
                prompt: "Don't have an account?",
                action: "Sign up"
            ) { model.showWelcome() }
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
                placeholder: "Email",
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
        OnboardingCTAButton(title: "Sign in") { Task { await model.submitPrimary() } }
            .disabled(!model.canSubmit)
            .opacity(model.canSubmit ? 1 : 0.5)
            .animation(OnboardingLabMotion.fast, value: model.canSubmit)
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

    // MARK: Social sign-in (not wired — see file header)

    private var socialButtons: some View {
        VStack(spacing: 12) {
            OnboardingAuthButton(kind: .apple) { model.requestUnavailable() }
            OnboardingAuthButton(kind: .google) { model.requestUnavailable() }
        }
    }
}
