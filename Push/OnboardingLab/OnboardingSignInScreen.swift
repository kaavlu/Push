//
//  OnboardingSignInScreen.swift
//  Push
//
//  Returning-user entry point: email/password plus Apple + Google.
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
            OnboardingSignInField(
                systemImage: "envelope.fill",
                placeholder: "Username or email",
                text: $model.email,
                isSecure: false
            )
            OnboardingSignInField(
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
        VStack(spacing: 12) {
            OnboardingAuthButton(kind: .apple) { model.completeSignIn() }
            OnboardingAuthButton(kind: .google) { model.completeSignIn() }
        }
    }
}

// MARK: - Field

/// A single credential row: leading glyph + text or secure entry, styled
/// to match the phone/code fields (warm fill, rounded corners).
private struct OnboardingSignInField: View {
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

// MARK: - Flow switch link

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
#endif
