// Push/Auth/PostAuthOnboardingScreens.swift
import SwiftUI

// MARK: - Privacy

struct PostAuthPrivacyScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "You're in control.",
                subtitle: "Pick what friends can see. Change it anytime."
            )
            options.padding(.top, 20)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 12)
            }
            Spacer(minLength: 22)
            OnboardingCTAButton(title: model.isBusy ? "Saving…" : "Continue") {
                Task { await model.continueFromPrivacy() }
            }
            .disabled(model.isBusy)
            .opacity(model.isBusy ? 0.5 : 1)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var options: some View {
        VStack(spacing: 11) {
            ForEach(OnboardingPrivacyOption.allCases) { option in
                PostAuthPrivacyRow(
                    option: option,
                    isSelected: model.privacy == option,
                    onTap: { model.select(option) }
                )
            }
        }
    }
}

private struct PostAuthPrivacyRow: View {
    let option: OnboardingPrivacyOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(option.iconTint)
                    .frame(width: 44, height: 44)
                    .background(
                        option.iconTint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(OnboardingLabFont.rounded(16, .bold))
                        .foregroundStyle(OnboardingLabColor.espresso)
                    Text(option.subtitle)
                        .font(OnboardingLabFont.text(13, .regular))
                        .foregroundStyle(OnboardingLabColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(OnboardingLabColor.sage, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .background(
                OnboardingLabColor.fieldFill,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(OnboardingLabColor.sunbeam, lineWidth: 2.5)
                        .shadow(color: OnboardingLabColor.sunbeam.opacity(0.28), radius: 9, y: 8)
                }
            }
        }
        .buttonStyle(PushPressStyle())
        .animation(OnboardingLabMotion.standard, value: isSelected)
    }
}

// MARK: - Location

struct PostAuthLocationScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            map
            OnboardingHeader(
                title: "Push runs on location.",
                subtitle: "It's how you see who's nearby and who's down to hang. Nothing shares until you say so."
            )
            .padding(.top, 24)
            OnboardingStatusChip(
                text: "You chose: \(model.privacyTitle)",
                systemImage: "lock.fill",
                fill: OnboardingLabColor.sage.opacity(0.12),
                textColor: OnboardingLabColor.sage
            )
            .padding(.top, 16)
            OnboardingCTAButton(title: model.isBusy ? "Enabling…" : "Enable location") {
                Task { await model.enableLocation() }
            }
            .disabled(model.isBusy)
            .padding(.top, 24)
            OnboardingTextButton(title: "Not now") { model.skipLocation() }
                .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var map: some View {
        OnboardingMiniMap {
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
        .frame(height: 210)
    }
}

// MARK: - Notifications

struct PostAuthNotificationsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

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
            OnboardingCTAButton(title: model.isBusy ? "Working…" : "Turn on notifications") {
                Task { await model.enableNotifications() }
            }
            .disabled(model.isBusy)
            OnboardingTextButton(title: "Maybe later") {
                Task { await model.skipNotifications() }
            }
            .disabled(model.isBusy)
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
                    center: .init(x: 0.5, y: 0.4),
                    startRadius: 4,
                    endRadius: 60
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
            sampleRow(title: "sid is 2 min away 🚗", subtitle: "heading toward the mission")
            sampleRow(title: "maya started a plan ☕", subtitle: "coffee at blue bottle · join?")
            sampleRow(title: "3 friends are free now", subtitle: "nobody's texting the group chat")
        }
    }

    private func sampleRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(OnboardingLabFont.text(14, .bold))
                .foregroundStyle(OnboardingLabColor.espresso)
            Text(subtitle)
                .font(OnboardingLabFont.text(12, .regular))
                .foregroundStyle(OnboardingLabColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: OnboardingLabColor.warmShadow.opacity(0.1), radius: 7, y: 6)
    }
}

// MARK: - Friends

struct PostAuthFriendsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Find your people.",
                subtitle: "People already on Push. We'll never text or invite anyone unless you ask us to."
            )
            content.padding(.top, 20)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }
            Spacer(minLength: 22)
            OnboardingCTAButton(title: model.isBusy ? "Finishing…" : model.friendsCTALabel) {
                Task { await model.continueFromFriends() }
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, 26)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingPeople {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if model.people.isEmpty {
            Text("No one to suggest yet — invite friends from the app once you're in.")
                .font(OnboardingLabFont.text(15, .medium))
                .foregroundStyle(OnboardingLabColor.textSecondary)
                .padding(.vertical, 12)
        } else {
            OnboardingGlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                        row(person, showsDivider: index > 0)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func row(_ person: OnboardingDiscoverPerson, showsDivider: Bool) -> some View {
        let added = model.isAdded(person.id)
        return HStack(spacing: 13) {
            avatar(for: person)
            VStack(alignment: .leading, spacing: 1) {
                Text(person.name)
                    .font(OnboardingLabFont.rounded(16, .bold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                Text("@\(person.handle)")
                    .font(OnboardingLabFont.text(13, .regular))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                Task { await model.toggleFriend(person.id) }
            } label: {
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
            .disabled(added || model.actingIDs.contains(person.id) || model.isBusy)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle().fill(OnboardingLabColor.walnut.opacity(0.08)).frame(height: 1)
            }
        }
    }

    private func avatar(for person: OnboardingDiscoverPerson) -> some View {
        let initials = String(person.name.prefix(1)).uppercased()
        return ProfilePhotoAvatar(
            imageAssetName: person.imageAssetPath,
            fallbackInitials: initials
        )
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
    }
}

// MARK: - Done

struct PostAuthDoneScreen: View {
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("You're in.")
                .font(OnboardingLabFont.rounded(52, .heavy))
                .foregroundStyle(OnboardingLabColor.espresso)
            Text("Push works best with your real friends. They're waiting on the map.")
                .font(OnboardingLabFont.text(17, .medium))
                .foregroundStyle(OnboardingLabColor.walnut)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .padding(.top, 14)
            Spacer(minLength: 0)
            OnboardingCTAButton(title: "Open Push") { model.openApp() }
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
        }
        .padding(.top, 80)
    }
}
