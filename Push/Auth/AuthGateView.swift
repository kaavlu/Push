// Push/Auth/AuthGateView.swift
import SwiftUI

/// Production auth surface. Lab-style shell (warm gradient + back chrome)
/// routes welcome, multi-step email sign-up, sign-in, check-email,
/// forgot-password, and set-new-password over `AuthViewModel.screen`.
struct AuthGateView: View {
    @ObservedObject var model: AuthViewModel
    var onAuthenticated: (AuthedUser) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            background
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .id(model.screen)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            topChrome
        }
        .animation(OnboardingLabMotion.screenIn, value: model.screen)
        // Single-parameter onChange: deployment target is iOS 16.4; the two-closure
        // onChange(of:_:) is iOS 17+ and would fail to compile here.
        .onChange(of: model.authedUser) { user in if let user { onAuthenticated(user) } }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                OnboardingLabColor.screenTop,
                OnboardingLabColor.screenMid,
                OnboardingLabColor.screenBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var screen: some View {
        switch model.screen {
        case .welcome:
            AuthWelcomeView(model: model)
        case .signUpProfile:
            AuthSignUpProfileView(model: model)
        case .signUpCredentials:
            AuthSignUpCredentialsView(model: model)
        case .signIn:
            AuthSignInView(model: model)
        case .checkEmail:
            AuthCheckEmailView(model: model)
        case .forgotPassword:
            AuthForgotPasswordView(model: model)
        case .setNewPassword:
            AuthSetNewPasswordView(model: model)
        }
    }

    @ViewBuilder
    private var topChrome: some View {
        if model.screen.showsBackButton {
            HStack {
                backButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var backButton: some View {
        Button(action: model.goBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingLabColor.espresso)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: OnboardingLabColor.warmShadow.opacity(0.14), radius: 4, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy)
        .accessibilityLabel("Back")
    }
}
