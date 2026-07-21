// Push/Auth/AuthCheckEmailView.swift
import SwiftUI

/// Shown when sign-up creates a user but email confirmation is still required.
struct AuthCheckEmailView: View {
    @ObservedObject var model: AuthViewModel
    @Environment(\.pushLayout) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Check your email",
                subtitle: subtitle
            )
            Text("Open the confirmation link, then sign in to continue.")
                .font(OnboardingLabFont.text(15, .medium))
                .foregroundStyle(OnboardingLabColor.textSecondary)
                .padding(.top, 18)
            OnboardingCTAButton(title: "Back to sign in") {
                model.showSignInFromCheckEmail()
            }
            .padding(.top, 28)
            Spacer(minLength: 24)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var subtitle: String {
        let address = model.trimmedEmail
        if address.isEmpty {
            return "We sent a confirmation link to your email."
        }
        return "We sent a confirmation link to \(address)."
    }
}
