//
//  OnboardingIntroScreens.swift
//  Push
//
//  Bookend screens: welcome (sign-in), value preview, and the final
//  "you're in" celebration.
//

#if DEBUG
import SwiftUI

// MARK: - Welcome

struct OnboardingWelcomeScreen: View {
    @ObservedObject var model: OnboardingLabViewModel

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
            FriendPuck(
                friend: OnboardingLabFixtures.heroPucks[0],
                size: OnboardingWelcomeHeroLayout.leadingPuckSize
            )
            .offset(x: OnboardingWelcomeHeroLayout.leadingOffsetX, y: OnboardingWelcomeHeroLayout.leadingOffsetY)

            FriendPuck(
                friend: OnboardingLabFixtures.heroPucks[1],
                size: OnboardingWelcomeHeroLayout.trailingPuckSize
            )
            .offset(x: OnboardingWelcomeHeroLayout.trailingOffsetX, y: OnboardingWelcomeHeroLayout.trailingOffsetY)

            FriendPuck(
                friend: OnboardingLabFixtures.heroPucks[2],
                size: OnboardingWelcomeHeroLayout.centerPuckSize
            )
            .offset(x: OnboardingWelcomeHeroLayout.centerOffsetX, y: OnboardingWelcomeHeroLayout.centerOffsetY)
        }
        .frame(width: OnboardingWelcomeHeroLayout.width, height: OnboardingWelcomeHeroLayout.height)
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
            OnboardingAuthButton(kind: .apple) { model.choose(.apple) }
            OnboardingAuthButton(kind: .google) { model.choose(.google) }
            OnboardingAuthButton(kind: .mobile) { model.choose(.mobile) }
            OnboardingAuthSwitchLink(
                prompt: "Already have an account?",
                action: "Sign in"
            ) { model.goToSignIn() }
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

private enum OnboardingWelcomeHeroLayout {
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

// `OnboardingAuthButton` now lives in OnboardingAuthComponents.swift
// (promoted out of DEBUG so the production auth gate can reuse it).

// MARK: - Value preview

struct OnboardingPreviewScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "See what your friends\nare up to.",
                subtitle: "No group texts. No \"wyd?\" Just the live picture."
            )
            card.padding(.top, 22)
            Spacer(minLength: 24)
            OnboardingCTAButton(title: "Let's get you in") { model.continueFromPreview() }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var card: some View {
        OnboardingGlassCard {
            VStack(spacing: 0) {
                map
                VStack(spacing: 0) {
                    ForEach(OnboardingLabFixtures.previewFriends) { friend in
                        friendRow(friend)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
    }

    private var map: some View {
        OnboardingMiniMap(cornerRadius: OnboardingLabMetric.cardCornerRadius) {
            OnboardingAvatar(assetName: "assets/friends/ohm.png", size: 46, ring: OnboardingLabColor.stateJoinable, ringWidth: 2.5, pulses: true)
                .offset(x: -95, y: -38)
            OnboardingAvatar(assetName: "assets/friends/ram.png", size: 42, ring: OnboardingLabColor.stateDriving, ringWidth: 2.5, pulses: true)
                .offset(x: 96, y: -44)
            OnboardingAvatar(assetName: "assets/friends/nitin.png", size: 44, ring: OnboardingLabColor.stateMaybe, ringWidth: 2.5, pulses: true)
                .offset(x: 0, y: 40)
        }
        .frame(height: 158)
    }

    private func friendRow(_ friend: OnboardingPreviewFriend) -> some View {
        HStack(spacing: 12) {
            OnboardingAvatar(assetName: friend.assetName, size: 46, ring: friend.ring, ringWidth: 2.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(friend.name)
                    .font(OnboardingLabFont.rounded(16, .bold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                Text(friend.detail)
                    .font(OnboardingLabFont.text(13, .regular))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
            }
            Spacer(minLength: 0)
            OnboardingStatusChip(
                text: "\(friend.chipIcon) \(friend.chip)", systemImage: nil,
                fill: friend.chipFill, textColor: friend.chipText
            )
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(OnboardingLabColor.walnut.opacity(0.08)).frame(height: 1)
        }
    }
}

// MARK: - Done

struct OnboardingDoneScreen: View {
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            hero
            copy.padding(.top, 26)
            Spacer(minLength: 0)
            buttons
        }
        .padding(.horizontal, 26)
        .padding(.top, 80)
        .padding(.bottom, 30)
    }

    private var hero: some View {
        ZStack {
            OnboardingAvatar(assetName: OnboardingLabFixtures.profileImageAssetName, size: 82, ring: OnboardingLabColor.sunbeam, ringWidth: 4, pulses: true)
                .offset(y: -30)
            OnboardingAvatar(assetName: "assets/friends/ryan.png", size: 52, ring: OnboardingLabColor.stateFree).offset(x: -66, y: 14)
            OnboardingAvatar(assetName: "assets/friends/pranay.png", size: 52, ring: OnboardingLabColor.stateJoinable).offset(x: 66, y: 14)
            OnboardingAvatar(assetName: "assets/friends/roh.png", size: 46, ring: OnboardingLabColor.stateMaybe).offset(y: 50)
        }
        .frame(width: 200, height: 130)
    }

    private var copy: some View {
        VStack(spacing: 14) {
            Text("You're in.")
                .font(OnboardingLabFont.rounded(52, .heavy))
                .foregroundStyle(OnboardingLabColor.espresso)
            Text("Push works best with your real friends. They're waiting on the map.")
                .font(OnboardingLabFont.text(17, .medium))
                .foregroundStyle(OnboardingLabColor.walnut)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            OnboardingCTAButton(title: "Open Push") { model.restart() }
            Button(action: {}) {
                Text("Invite more friends")
                    .font(OnboardingLabFont.text(16, .semibold))
                    .foregroundStyle(OnboardingLabColor.walnut)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(OnboardingLabColor.walnut.opacity(0.12), in: Capsule())
            }
            .buttonStyle(PushPressStyle())
        }
    }
}
#endif
