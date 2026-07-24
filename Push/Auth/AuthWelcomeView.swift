// Push/Auth/AuthWelcomeView.swift
import SwiftUI

/// Production front door — lab welcome layout: hero pucks, wordmark,
/// Google + email continue, sign-in switch, legal consent.
struct AuthWelcomeView: View {
    @ObservedObject var model: AuthViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            hero
            wordmark
            Spacer(minLength: 0)
            authButtons
        }
        .padding(.horizontal, 26)
        .padding(.top, 64)
        .padding(.bottom, 30)
    }

    private var hero: some View {
        ZStack {
            FriendPuck(friend: AuthHeroFixtures.pucks[0], size: AuthWelcomeHeroLayout.leadingPuckSize)
                .offset(x: AuthWelcomeHeroLayout.leadingOffsetX, y: AuthWelcomeHeroLayout.leadingOffsetY)
            FriendPuck(friend: AuthHeroFixtures.pucks[1], size: AuthWelcomeHeroLayout.trailingPuckSize)
                .offset(x: AuthWelcomeHeroLayout.trailingOffsetX, y: AuthWelcomeHeroLayout.trailingOffsetY)
            FriendPuck(friend: AuthHeroFixtures.pucks[2], size: AuthWelcomeHeroLayout.centerPuckSize)
                .offset(x: AuthWelcomeHeroLayout.centerOffsetX, y: AuthWelcomeHeroLayout.centerOffsetY)
        }
        .frame(width: AuthWelcomeHeroLayout.width, height: AuthWelcomeHeroLayout.height)
    }

    private var wordmark: some View {
        VStack(spacing: 14) {
            Text("Push")
                .font(OnboardingLabFont.rounded(66, .heavy))
                .foregroundStyle(OnboardingLabColor.espresso)
            Text("a private live map for the friends you actually see")
                .font(OnboardingLabFont.text(17, .medium))
                .foregroundStyle(OnboardingLabColor.walnut)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .padding(.top, 30)
    }

    private var authButtons: some View {
        VStack(spacing: 12) {
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            AuthSocialButtons(
                isBusy: model.isBusy,
                onGoogle: { Task { await model.signInWithGoogle() } }
            )
            OnboardingCTAButton(title: "Continue with email") {
                model.showSignUp()
            }
            .disabled(model.isBusy)
            .opacity(model.isBusy ? 0.5 : 1)
            OnboardingAuthSwitchLink(
                prompt: "Already have an account?",
                action: "Sign in"
            ) { model.showSignIn() }
            .padding(.top, 2)
            LegalConsentText()
        }
    }
}

/// Layout constants for the three-puck hero cluster (shared with lab welcome).
enum AuthWelcomeHeroLayout {
    static let width: CGFloat = 260
    static let height: CGFloat = 172
    static let leadingPuckSize: CGFloat = 74
    static let trailingPuckSize: CGFloat = 68
    static let centerPuckSize: CGFloat = 64
    static let leadingOffsetX: CGFloat = -94
    static let leadingOffsetY: CGFloat = -8
    static let trailingOffsetX: CGFloat = 92
    static let trailingOffsetY: CGFloat = -42
    static let centerOffsetX: CGFloat = 4
    static let centerOffsetY: CGFloat = 52
}

/// Decorative hero pucks for production + DEBUG lab welcome (not seed data).
enum AuthHeroFixtures {
    static let pucks: [FriendPuckData] = [
        FriendPuckData(
            id: "auth-hero-free-now",
            name: "ava",
            avatarPlaceholder: "AV",
            activity: "Coffee",
            activitySymbolName: "cup.and.saucer.fill",
            activityDisplayText: "Blue Bottle",
            availability: .freeNow,
            venueStatusText: "At Blue Bottle",
            locationLabel: "Hayes Valley",
            placeName: "Blue Bottle"
        ),
        FriendPuckData(
            id: "auth-hero-joinable",
            name: "leo",
            avatarPlaceholder: "LE",
            activity: "Gym",
            activitySymbolName: "figure.strengthtraining.traditional",
            activityDisplayText: "Crunch",
            availability: .joinable,
            venueStatusText: "At Crunch",
            locationLabel: "Mission",
            placeName: "Crunch"
        ),
        FriendPuckData(
            id: "auth-hero-maybe-down",
            name: "mia",
            avatarPlaceholder: "MI",
            activity: "Park",
            activitySymbolName: "leaf.fill",
            activityDisplayText: "Dolores",
            availability: .maybeDown,
            venueStatusText: "Near Dolores",
            locationLabel: "Dolores",
            placeName: "Dolores"
        ),
    ]
}
