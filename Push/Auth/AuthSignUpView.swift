// Push/Auth/AuthSignUpView.swift
import SwiftUI

/// Single-screen email sign-up: display name, handle, email, password.
struct AuthSignUpView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeader(
                    title: "Create your account",
                    subtitle: "A name and handle so friends can find you."
                )
                fields.padding(.top, 26)
                if let error = model.errorMessage {
                    Text(error)
                        .font(OnboardingLabFont.text(14, .medium))
                        .foregroundStyle(.red)
                        .padding(.top, 10)
                }
                OnboardingCTAButton(title: "Create account") {
                    Task { await model.submitSignUp() }
                }
                .disabled(!model.canSubmitSignUp)
                .opacity(model.canSubmitSignUp ? 1 : 0.5)
                .animation(OnboardingLabMotion.fast, value: model.canSubmitSignUp)
                .padding(.top, 22)
                Spacer(minLength: 24)
                OnboardingAuthSwitchLink(
                    prompt: "Already have an account?",
                    action: "Sign in"
                ) { model.showSignIn() }
            }
            .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
            .padding(.top, OnboardingLabMetric.contentTopInset(layout))
            .padding(.bottom, 26)
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            OnboardingCredentialField(
                systemImage: "person.fill",
                placeholder: "Display name",
                text: $model.displayName,
                isSecure: false,
                keyboardType: .default,
                textInputAutocapitalization: .words
            )
            OnboardingCredentialField(
                systemImage: "at",
                placeholder: "Handle",
                text: $model.handle,
                isSecure: false,
                keyboardType: .asciiCapable,
                textInputAutocapitalization: .never
            )
            OnboardingCredentialField(
                systemImage: "envelope.fill",
                placeholder: "Email",
                text: $model.email,
                isSecure: false,
                keyboardType: .emailAddress
            )
            OnboardingCredentialField(
                systemImage: "lock.fill",
                placeholder: "Password (8+ characters)",
                text: $model.password,
                isSecure: true
            )
        }
    }
}
