// Push/Auth/PostAuthOnboardingScreens.swift
import SwiftUI

// Placeholder screens for Approach 2 spine. Polished UI lands in Tasks 4–7.

// MARK: - Value

struct PostAuthValueScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Know the move.",
                subtitle: "A private live map for real friends — not a tracker."
            )
            Spacer(minLength: 22)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromValue()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }
}

// Location primer + blocked live in PostAuthLocationScreens.swift

// MARK: - Ghost

struct PostAuthGhostScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Ghost when you need space.",
                subtitle: "Go invisible anytime in Profile. You're visible by default so friends can find you."
            )
            Spacer(minLength: 22)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromGhost()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }
}

// MARK: - Coordinate (Pushes + Moments)

struct PostAuthCoordinateScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Pushes and Moments.",
                subtitle: "Start a Push when something's forming. Moments capture the hang after."
            )
            Spacer(minLength: 22)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromCoordinate()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
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

// MARK: - Contacts

struct PostAuthContactsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Find friends from contacts.",
                subtitle: "Optional. We'll never message anyone for you."
            )
            Spacer(minLength: 22)
            OnboardingCTAButton(title: model.isBusy ? "Loading…" : "Continue") {
                Task { await model.continueFromContacts() }
            }
            .disabled(model.isBusy)
            OnboardingTextButton(title: "Not now") {
                Task { await model.skipContacts() }
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }
}

// MARK: - Find people

struct PostAuthFindPeopleScreen: View {
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
            OnboardingCTAButton(title: model.isBusy ? "Finishing…" : model.findPeopleCTALabel) {
                Task { await model.continueFromFindPeople() }
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
