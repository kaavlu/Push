// Push/Auth/AuthGateView.swift
import SwiftUI

/// Production auth surface. Routes between the promoted onboarding welcome
/// screen (`AuthWelcomeView`) and sign-in screen (`AuthSignInView`) over
/// `AuthViewModel.screen`, so the live gate matches the DEBUG onboarding
/// lab's welcome ⇄ sign-in flow while staying backed by real Supabase auth.
struct AuthGateView: View {
    @ObservedObject var model: AuthViewModel
    var onAuthenticated: (AuthedUser) -> Void

    var body: some View {
        ZStack {
            screen
                .id(model.screen)
                .transition(.opacity)
            if model.showingComingSoon {
                ComingSoonToast(isPresented: $model.showingComingSoon)
            }
        }
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
        case .signIn:
            AuthSignInView(model: model)
        }
    }
}

/// Transient "coming soon" notice for the auth paths that aren't wired to
/// real auth yet (sign-up, social sign-in). Auto-dismisses so a stray tap
/// never leaves the gate stuck under an overlay.
private struct ComingSoonToast: View {
    @Binding var isPresented: Bool

    private enum Timing {
        static let visibleDuration: TimeInterval = 1.6
    }

    var body: some View {
        VStack {
            Spacer()
            Text("Sign-ups aren't open yet")
                .font(OnboardingLabFont.text(15, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(OnboardingLabColor.espresso, in: Capsule())
                .shadow(color: OnboardingLabColor.warmShadow.opacity(0.3), radius: 12, y: 6)
                .padding(.bottom, 40)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .task {
            try? await Task.sleep(nanoseconds: UInt64(Timing.visibleDuration * 1_000_000_000))
            isPresented = false
        }
    }
}
