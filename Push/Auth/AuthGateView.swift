// Push/Auth/AuthGateView.swift
import SwiftUI

/// Production auth surface. Routes welcome, sign-up, sign-in, check-email,
/// forgot-password, and set-new-password over `AuthViewModel.screen`.
struct AuthGateView: View {
    @ObservedObject var model: AuthViewModel
    var onAuthenticated: (AuthedUser) -> Void

    var body: some View {
        screen
            .id(model.screen)
            .transition(.opacity)
            .animation(OnboardingLabMotion.standard, value: model.screen)
            // Single-parameter onChange: deployment target is iOS 16.4; the two-closure
            // onChange(of:_:) is iOS 17+ and would fail to compile here.
            .onChange(of: model.authedUser) { user in if let user { onAuthenticated(user) } }
    }

    @ViewBuilder
    private var screen: some View {
        switch model.screen {
        case .welcome:
            AuthWelcomeView(model: model)
        case .signUp:
            AuthSignUpView(model: model)
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
}
