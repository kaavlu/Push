// Push/Auth/PostAuthOnboardingScreens.swift
import SwiftUI

// Teach + optional graph screens for post-auth onboarding.
// Combined location/value primer + blocked live in PostAuthLocationScreens.swift

// MARK: - Ghost

struct PostAuthGhostScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ghostHero
                .frame(maxWidth: .infinity)
                .padding(.top, GhostTeachLayout.heroTop)
            OnboardingHeader(
                title: "You're visible to friends.",
                subtitle: "Go invisible anytime with Ghost in Profile. You're on by default so friends can find you.",
                alignment: .center
            )
            .padding(.top, GhostTeachLayout.headerTop)
            Spacer(minLength: GhostTeachLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromGhost()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, GhostTeachLayout.bottomPadding)
    }

    private var ghostHero: some View {
        Image(systemName: "eye.slash.fill")
            .font(.system(size: GhostTeachLayout.iconSize, weight: .semibold))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: GhostTeachLayout.heroSize, height: GhostTeachLayout.heroSize)
            .background(
                Circle()
                    .fill(OnboardingLabColor.walnut.opacity(GhostTeachLayout.heroFillOpacity))
            )
            .overlay(
                Circle()
                    .stroke(OnboardingLabColor.walnut.opacity(GhostTeachLayout.heroStrokeOpacity), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Coordinate (Pushes + Moments)

struct PostAuthCoordinateScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Make plans. Keep moments.",
                subtitle: "Coordinate without the group chat thrash; save the hang after."
            )
            VStack(spacing: CoordinateTeachLayout.cardSpacing) {
                teachCard(
                    symbol: "paperplane.fill",
                    title: "Push",
                    body: "Start a Push when something's forming"
                )
                teachCard(
                    symbol: "photo.on.rectangle.angled",
                    title: "Moment",
                    body: "Share photos from the hang on Feed"
                )
            }
            .padding(.top, CoordinateTeachLayout.cardsTop)
            Spacer(minLength: CoordinateTeachLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromCoordinate()
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, CoordinateTeachLayout.bottomPadding)
    }

    private func teachCard(symbol: String, title: String, body: String) -> some View {
        HStack(spacing: CoordinateTeachLayout.cardInnerSpacing) {
            Image(systemName: symbol)
                .font(.system(size: CoordinateTeachLayout.symbolSize, weight: .semibold))
                .foregroundStyle(OnboardingLabColor.espresso)
                .frame(width: CoordinateTeachLayout.symbolWell, height: CoordinateTeachLayout.symbolWell)
                .background(
                    Circle()
                        .fill(OnboardingLabColor.sunbeam.opacity(CoordinateTeachLayout.symbolFillOpacity))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OnboardingLabFont.rounded(16, .bold))
                    .foregroundStyle(OnboardingLabColor.espresso)
                Text(body)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(OnboardingLabColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, CoordinateTeachLayout.cardPaddingH)
        .padding(.vertical, CoordinateTeachLayout.cardPaddingV)
        .background(
            Color.white.opacity(CoordinateTeachLayout.cardFillOpacity),
            in: RoundedRectangle(cornerRadius: CoordinateTeachLayout.cardCornerRadius, style: .continuous)
        )
        .shadow(
            color: OnboardingLabColor.warmShadow.opacity(CoordinateTeachLayout.cardShadowOpacity),
            radius: CoordinateTeachLayout.cardShadowRadius,
            y: CoordinateTeachLayout.cardShadowY
        )
    }
}

private enum GhostTeachLayout {
    static let heroTop: CGFloat = 12
    static let heroSize: CGFloat = 96
    static let iconSize: CGFloat = 36
    static let heroFillOpacity = 0.08
    static let heroStrokeOpacity = 0.12
    static let headerTop: CGFloat = 20
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}

private enum CoordinateTeachLayout {
    static let cardsTop: CGFloat = 24
    static let cardSpacing: CGFloat = 12
    static let cardInnerSpacing: CGFloat = 14
    static let cardPaddingH: CGFloat = 16
    static let cardPaddingV: CGFloat = 14
    static let cardCornerRadius: CGFloat = 18
    static let cardFillOpacity = 0.6
    static let cardShadowOpacity = 0.1
    static let cardShadowRadius: CGFloat = 7
    static let cardShadowY: CGFloat = 6
    static let symbolSize: CGFloat = 18
    static let symbolWell: CGFloat = 44
    static let symbolFillOpacity = 0.55
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
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
