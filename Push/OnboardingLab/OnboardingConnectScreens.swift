//
//  OnboardingConnectScreens.swift
//  Push
//
//  Permission primers (location, notifications) and the contacts →
//  add-friends hand-off that closes the flow.
//

#if DEBUG
import SwiftUI

// MARK: - Location

struct OnboardingLocationScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            map
            OnboardingHeader(
                title: "Push runs on location.",
                subtitle: "It's how you see who's nearby and who's down to hang. Nothing shares until you say so."
            )
            .padding(.top, 24)
            chosenChip.padding(.top, 16)
            OnboardingCTAButton(title: "Enable location") { model.go(to: .notifications) }
                .padding(.top, 24)
            OnboardingTextButton(title: "Not now") { model.go(to: .notifications) }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var map: some View {
        OnboardingMiniMap {
            selfPuck
            OnboardingAvatar(assetName: "assets/friends/ohm.png", size: 40, ring: OnboardingLabColor.stateFree, ringWidth: 2.5).offset(x: -90, y: -50)
            OnboardingAvatar(assetName: "assets/friends/ram.png", size: 38, ring: OnboardingLabColor.stateJoinable, ringWidth: 2.5).offset(x: 92, y: -56)
            OnboardingAvatar(assetName: "assets/friends/roh.png", size: 38, ring: OnboardingLabColor.stateMaybe, ringWidth: 2.5).offset(x: 78, y: 50)
        }
        .frame(height: 210)
    }

    private var selfPuck: some View {
        ZStack {
            OnboardingPulseRing(color: OnboardingLabColor.sunbeam)
            Text("you")
                .font(OnboardingLabFont.rounded(22, .heavy))
                .foregroundStyle(OnboardingLabColor.sunbeam)
                .frame(width: 58, height: 58)
                .background(OnboardingLabColor.ctaBottom, in: Circle())
                .overlay(Circle().stroke(OnboardingLabColor.sunbeam, lineWidth: 3))
        }
        .frame(width: 58, height: 58)
    }

    private var chosenChip: some View {
        OnboardingStatusChip(
            text: "You chose: \(model.privacy.title)",
            systemImage: "lock.fill",
            fill: OnboardingLabColor.sage.opacity(0.12),
            textColor: OnboardingLabColor.sage
        )
    }
}

// MARK: - Notifications

struct OnboardingNotificationsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(spacing: 0) {
            bell.padding(.top, 6)
            OnboardingHeader(
                title: "Never miss the moment.",
                subtitle: "A gentle nudge when a friend's near or a plan kicks off — nothing else.",
                alignment: .center
            )
            .padding(.top, 20)
            samples.padding(.top, 24)
            Spacer(minLength: 22)
            OnboardingCTAButton(title: "Turn on notifications") { model.go(to: .contacts) }
            OnboardingTextButton(title: "Maybe later") { model.go(to: .contacts) }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, 26)
    }

    private var bell: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: 40))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: 96, height: 96)
            .background(
                RadialGradient(
                    colors: [OnboardingLabColor.sunbeam, OnboardingLabColor.sunbeam.opacity(0.5)],
                    center: .init(x: 0.5, y: 0.4), startRadius: 4, endRadius: 60
                ),
                in: Circle()
            )
            .overlay(alignment: .topTrailing) {
                Circle().fill(OnboardingLabColor.notificationBadge)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(OnboardingLabColor.sunbeam.opacity(0.9), lineWidth: 3))
                    .offset(x: -14, y: 14)
            }
            .shadow(color: OnboardingLabColor.sunbeam.opacity(0.35), radius: 13, y: 12)
    }

    private var samples: some View {
        VStack(spacing: 10) {
            ForEach(OnboardingLabFixtures.notificationSamples) { sample in
                OnboardingNotificationRow(sample: sample)
            }
        }
    }
}

private struct OnboardingNotificationRow: View {
    let sample: OnboardingNotificationSample

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 1) {
                Text(sample.title)
                    .font(OnboardingLabFont.text(14, .bold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                Text(sample.subtitle)
                    .font(OnboardingLabFont.text(12, .regular))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: OnboardingLabColor.warmShadow.opacity(0.1), radius: 7, y: 6)
    }

    @ViewBuilder
    private var leading: some View {
        if let assetName = sample.assetName {
            OnboardingAvatar(assetName: assetName, size: 40, ring: sample.ring, ringWidth: 2)
        } else if let badge = sample.badge {
            Text(badge)
                .font(OnboardingLabFont.rounded(18, .heavy))
                .foregroundStyle(OnboardingLabColor.sage)
                .frame(width: 40, height: 40)
                .background(OnboardingLabColor.mint, in: Circle())
        }
    }
}

// MARK: - Find friends

struct OnboardingContactsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Find your people.",
                subtitle: "See which of your contacts are already on Push. We'll never text or invite anyone unless you ask us to."
            )
            list.padding(.top, 20)
            Spacer(minLength: 22)
            OnboardingCTAButton(title: model.friendsCTALabel) { model.go(to: .done) }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, 26)
    }

    private var list: some View {
        OnboardingGlassCard {
            VStack(spacing: 0) {
                ForEach(Array(OnboardingLabFixtures.contacts.enumerated()), id: \.element.id) { index, contact in
                    contactRow(contact, showsDivider: index > 0)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func contactRow(_ contact: OnboardingContact, showsDivider: Bool) -> some View {
        HStack(spacing: 13) {
            OnboardingAvatar(assetName: contact.assetName, size: 48, ring: .white.opacity(0.7), ringWidth: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(contact.name)
                    .font(OnboardingLabFont.rounded(16, .bold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                Text(contact.detail)
                    .font(OnboardingLabFont.text(13, .regular))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
            }
            Spacer(minLength: 0)
            addToggle(contact)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle().fill(OnboardingLabColor.walnut.opacity(0.08)).frame(height: 1)
            }
        }
    }

    private func addToggle(_ contact: OnboardingContact) -> some View {
        let added = model.isAdded(contact.id)
        return Button { model.toggleFriend(contact.id) } label: {
            HStack(spacing: 5) {
                if added {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy))
                }
                Text(added ? "Added" : "Add")
            }
            .font(OnboardingLabFont.text(14, .bold))
            .foregroundStyle(added ? OnboardingLabColor.sage : OnboardingLabColor.walnut)
            .padding(.horizontal, added ? 15 : 18)
            .frame(height: 36)
            .background(added ? OnboardingLabColor.mint : OnboardingLabColor.sunbeam, in: Capsule())
        }
        .buttonStyle(PushPressStyle())
        .animation(OnboardingLabMotion.fast, value: added)
    }
}

// MARK: - Add friends

struct OnboardingFriendsScreen: View {
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        OnboardingContactsScreen(model: model)
    }
}
#endif
