//
//  OnboardingLabView.swift
//  Push
//
//  Root of the Onboarding Lab: a DEBUG-only harness that renders the
//  full 11-step onboarding flow in isolation from shipping Push. Launch
//  with the `--onboardinglab` argument (see PushApp). Takes its shape
//  from PuckLabView — a sandbox for iterating on a design without
//  risking app functionality. Implements issue #22.
//

#if DEBUG
import SwiftUI

struct OnboardingLabView: View {
    @StateObject private var model = OnboardingLabViewModel()

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
    }

    private var background: some View {
        LinearGradient(
            colors: [OnboardingLabColor.screenTop, OnboardingLabColor.screenMid, OnboardingLabColor.screenBottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Screen router

    @ViewBuilder
    private var screen: some View {
        switch model.screen {
        case .welcome: OnboardingWelcomeScreen(model: model)
        case .signIn: OnboardingSignInScreen(model: model)
        case .preview: OnboardingPreviewScreen(model: model)
        case .phone: OnboardingPhoneScreen(model: model)
        case .verify: OnboardingVerifyScreen(model: model)
        case .profile: OnboardingProfileScreen(model: model)
        case .privacy: OnboardingPrivacyScreen(model: model)
        case .location: OnboardingLocationScreen(model: model)
        case .notifications: OnboardingNotificationsScreen(model: model)
        case .contacts: OnboardingContactsScreen(model: model)
        case .friends: OnboardingFriendsScreen(model: model)
        case .done: OnboardingDoneScreen(model: model)
        }
    }

    // MARK: Top chrome (back + progress)

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 14) {
            if model.screen.showsBackButton {
                backButton
            }
            if model.screen.progressStep > 0 {
                progressBar
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var backButton: some View {
        Button(action: model.back) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingLabColor.espresso)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: OnboardingLabColor.warmShadow.opacity(0.14), radius: 4, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<OnboardingScreen.progressTotal, id: \.self) { index in
                Capsule()
                    .fill(index < model.screen.progressStep ? OnboardingLabColor.walnut : OnboardingLabColor.walnut.opacity(0.2))
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingLabView_Previews: PreviewProvider {
    static var previews: some View {
        PushPreviewMatrix {
            OnboardingLabView()
        }
    }
}
#endif
