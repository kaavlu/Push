// Push/Auth/AuthForgotPasswordView.swift
import SwiftUI

/// Request a password-reset email that deep-links back into the app.
struct AuthForgotPasswordView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Reset password",
                subtitle: "We'll email you a link to choose a new one."
            )
            OnboardingCredentialField(
                systemImage: "envelope.fill",
                placeholder: "Email",
                text: $model.email,
                isSecure: false,
                keyboardType: .emailAddress
            )
            .padding(.top, 26)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            if let info = model.infoMessage {
                Text(info)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(OnboardingLabColor.walnut)
                    .padding(.top, 10)
            }
            OnboardingCTAButton(title: "Send reset link") {
                Task { await model.submitForgotPassword() }
            }
            .disabled(!model.canSubmitForgotPassword)
            .opacity(model.canSubmitForgotPassword ? 1 : 0.5)
            .animation(OnboardingLabMotion.fast, value: model.canSubmitForgotPassword)
            .padding(.top, 22)
            Spacer(minLength: 24)
            OnboardingAuthSwitchLink(
                prompt: "Remembered it?",
                action: "Sign in"
            ) { model.showSignIn() }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }
}
