// Push/Auth/PostAuthOnboardingView.swift
import SwiftUI

/// Live first-run flow after session prepare: privacy → location →
/// notifications → find friends → done. Shell matches the auth gate / lab.
struct PostAuthOnboardingView: View {
    @StateObject private var model: PostAuthOnboardingViewModel
    var onFinished: () -> Void

    init(container: AppDataContainer? = nil, onFinished: @escaping () -> Void) {
        _model = StateObject(wrappedValue: PostAuthOnboardingViewModel(container: container))
        self.onFinished = onFinished
    }

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
        .onChange(of: model.isFinished) { finished in
            if finished { onFinished() }
        }
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
        case .privacy:
            PostAuthPrivacyScreen(model: model)
        case .location:
            PostAuthLocationScreen(model: model)
        case .notifications:
            PostAuthNotificationsScreen(model: model)
        case .friends:
            PostAuthFriendsScreen(model: model)
        case .done:
            PostAuthDoneScreen(model: model)
        }
    }

    private var topChrome: some View {
        HStack(alignment: .center, spacing: 14) {
            if model.screen.showsBackButton {
                backButton
            }
            if model.screen.progressStep > 0, model.screen != .done {
                progressBar
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
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

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<PostAuthOnboardingScreen.progressTotal, id: \.self) { index in
                Capsule()
                    .fill(
                        index < model.screen.progressStep
                            ? OnboardingLabColor.walnut
                            : OnboardingLabColor.walnut.opacity(0.2)
                    )
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
