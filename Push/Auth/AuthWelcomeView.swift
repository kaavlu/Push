// Push/Auth/AuthWelcomeView.swift
import SwiftUI

/// Production front door for the live app: the same hero + wordmark +
/// auth-method buttons as the DEBUG onboarding lab's welcome screen
/// (`OnboardingWelcomeScreen`), but driven by the real `AuthViewModel`.
/// Account creation isn't wired yet (see spec/Issue #27 scope), so the
/// Apple/Google/mobile buttons surface "coming soon" instead of silently
/// doing nothing — swap `model.requestUnavailable` for real sign-up calls
/// when that work starts.
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
            OnboardingAuthButton(kind: .apple) { model.requestUnavailable() }
            OnboardingAuthButton(kind: .google) { model.requestUnavailable() }
            OnboardingAuthButton(kind: .mobile) { model.requestUnavailable() }
            OnboardingAuthSwitchLink(
                prompt: "Already have an account?",
                action: "Sign in"
            ) { model.showSignIn() }
            .padding(.top, 2)
            terms
        }
    }

    private var terms: some View {
        (Text("By continuing you agree to Push's ")
            + Text("Terms").foregroundColor(OnboardingLabColor.walnut).bold()
            + Text(" & ")
            + Text("Privacy").foregroundColor(OnboardingLabColor.walnut).bold()
            + Text("."))
            .font(OnboardingLabFont.text(12, .regular))
            .foregroundStyle(OnboardingLabColor.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }
}

/// Layout constants for the three-puck hero cluster, mirrored from the
/// DEBUG onboarding lab's `OnboardingWelcomeHeroLayout` so the production
/// gate renders identically.
private enum AuthWelcomeHeroLayout {
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

/// Decorative hero pucks for the production gate. A small standalone
/// fixture (not `OnboardingLabFixtures`, which is DEBUG-only) so this
/// screen has no dependency on the design lab's compile target.
private enum AuthHeroFixtures {
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
