// Push/Auth/AuthSetNewPasswordView.swift
import SwiftUI

/// Choose a new password after opening a recovery deep link.
struct AuthSetNewPasswordView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Choose a new password",
                subtitle: "Then you can get back into Push."
            )
            fields.padding(.top, 26)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            OnboardingCTAButton(title: "Update password") {
                Task { await model.submitNewPassword() }
            }
            .disabled(!model.canSubmitNewPassword)
            .opacity(model.canSubmitNewPassword ? 1 : 0.5)
            .animation(OnboardingLabMotion.fast, value: model.canSubmitNewPassword)
            .padding(.top, 22)
            Spacer(minLength: 24)
            OnboardingAuthSwitchLink(
                prompt: "Link not working?",
                action: "Request a new one"
            ) { model.showForgotPassword() }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var fields: some View {
        VStack(spacing: 12) {
            OnboardingCredentialField(
                systemImage: "lock.fill",
                placeholder: "New password (8+ characters)",
                text: $model.password,
                isSecure: true
            )
            OnboardingCredentialField(
                systemImage: "lock.fill",
                placeholder: "Confirm password",
                text: $model.confirmPassword,
                isSecure: true
            )
        }
    }
}
