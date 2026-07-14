// Push/Auth/AuthGateView.swift
import SwiftUI

/// Production auth surface. Reuses the promoted onboarding header/CTA/field
/// components and the same warm styling; backed by real Supabase auth.
struct AuthGateView: View {
    @ObservedObject var model: AuthViewModel
    var onAuthenticated: (AuthedUser) -> Void
    // Adaptive layout tier (main's responsive system); onboarding metrics are
    // width-parameterized functions, so the gate reflows like the lab screens.
    @Environment(\.pushLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(title: "Welcome back",
                             subtitle: "Sign in to pick up right where you left off.")
            fields.padding(.top, 26)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            OnboardingCTAButton(title: "Sign in") { Task { await submit() } }
                .padding(.top, 22)
                .disabled(!model.canSubmit)
                .opacity(model.canSubmit ? 1 : 0.5)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
        // Single-parameter onChange: deployment target is iOS 16.4; the two-closure
        // onChange(of:_:) is iOS 17+ and would fail to compile here.
        .onChange(of: model.authedUser) { user in if let user { onAuthenticated(user) } }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            AuthField(systemImage: "envelope.fill", placeholder: "Email",
                      text: $model.email, isSecure: false)
            AuthField(systemImage: "lock.fill", placeholder: "Password",
                      text: $model.password, isSecure: true)
        }
    }

    private func submit() async { await model.submitPrimary() }
}

/// Production copy of the credential row (mirrors the promoted onboarding field
/// styling). Kept here so the shipping auth screen owns its input control.
private struct AuthField: View {
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
            Group {
                if isSecure { SecureField(placeholder, text: $text) }
                else {
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
        .padding(.horizontal, 18)
        .frame(height: OnboardingLabMetric.fieldHeight)
        .background(OnboardingLabColor.fieldFill,
                    in: RoundedRectangle(cornerRadius: OnboardingLabMetric.fieldCornerRadius, style: .continuous))
    }
}
