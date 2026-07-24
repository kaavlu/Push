// Push/Auth/AuthSignInView.swift
import SwiftUI

/// Production returning-user sign-in — lab layout: email/password,
/// forgot password, Google, switch to sign-up.
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
            forgotLink.padding(.top, 14)
            AuthOrDivider().padding(.vertical, 20)
            AuthSocialButtons(
                isBusy: model.isBusy,
                onGoogle: { Task { await model.signInWithGoogle() } }
            )
            Spacer(minLength: 24)
            OnboardingAuthSwitchLink(
                prompt: "Don't have an account?",
                action: "Sign up"
            ) { model.showSignUp() }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            OnboardingCredentialField(
                systemImage: "envelope.fill",
                placeholder: "Email",
                text: $model.email,
                isSecure: false,
                keyboardType: .emailAddress
            )
            OnboardingCredentialField(
                systemImage: "lock.fill",
                placeholder: "Password",
                text: $model.password,
                isSecure: true
            )
        }
    }

    private var signInCTA: some View {
        OnboardingCTAButton(title: "Sign in") { Task { await model.submitSignIn() } }
            .disabled(!model.canSubmitSignIn)
            .opacity(model.canSubmitSignIn ? 1 : 0.5)
            .animation(OnboardingLabMotion.fast, value: model.canSubmitSignIn)
    }

    private var forgotLink: some View {
        Button {
            model.showForgotPassword()
        } label: {
            Text("Forgot password?")
                .font(OnboardingLabFont.text(14, .semibold))
                .foregroundStyle(OnboardingLabColor.walnut)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy)
    }
}
