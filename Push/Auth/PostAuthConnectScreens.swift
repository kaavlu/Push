// Push/Auth/PostAuthConnectScreens.swift
import SwiftUI

// MARK: - Contacts (optional)

struct PostAuthContactsScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero
                .frame(maxWidth: .infinity)
                .padding(.top, ContactsScreenLayout.heroTop)
            OnboardingHeader(
                title: "Find friends already here.",
                subtitle: "See who's on Push from your contacts. We don't message them for you.",
                alignment: .center
            )
            .padding(.top, ContactsScreenLayout.headerTop)
            Spacer(minLength: ContactsScreenLayout.ctaSpacerMin)
            OnboardingCTAButton(title: model.isBusy ? "Loading…" : "Continue") {
                Task { await model.enableContacts() }
            }
            .disabled(model.isBusy)
            OnboardingTextButton(title: "Not now") {
                Task { await model.skipContacts() }
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, ContactsScreenLayout.bottomPadding)
    }

    private var hero: some View {
        Image(systemName: "person.crop.circle.badge.plus")
            .font(.system(size: ContactsScreenLayout.iconSize, weight: .semibold))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: ContactsScreenLayout.heroSize, height: ContactsScreenLayout.heroSize)
            .background(
                Circle()
                    .fill(OnboardingLabColor.sunbeam.opacity(ContactsScreenLayout.heroFillOpacity))
            )
            .overlay(
                Circle()
                    .stroke(OnboardingLabColor.walnut.opacity(ContactsScreenLayout.heroStrokeOpacity), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Find people (soft nudge)

struct PostAuthFindPeopleScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Add people on Push.",
                subtitle: "They're already here. Continue even if you add no one."
            )
            content.padding(.top, FindPeopleLayout.listTop)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, FindPeopleLayout.errorTop)
            }
            Spacer(minLength: FindPeopleLayout.ctaSpacerMin)
            OnboardingCTAButton(title: model.isBusy ? "Finishing…" : model.findPeopleCTALabel) {
                Task { await model.continueFromFindPeople() }
            }
            .disabled(model.isBusy)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, FindPeopleLayout.bottomPadding)
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingPeople {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, FindPeopleLayout.loadingVertical)
        } else if model.people.isEmpty {
            Text("No one to suggest yet — you can add friends anytime from the app.")
                .font(OnboardingLabFont.text(15, .medium))
                .foregroundStyle(OnboardingLabColor.textSecondary)
                .padding(.vertical, FindPeopleLayout.emptyVertical)
        } else {
            OnboardingGlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(model.people.enumerated()), id: \.element.id) { index, person in
                        row(person, showsDivider: index > 0)
                    }
                }
                .padding(.horizontal, FindPeopleLayout.rowHorizontal)
            }
        }
    }

    private func row(_ person: OnboardingDiscoverPerson, showsDivider: Bool) -> some View {
        let added = model.isAdded(person.id)
        return HStack(spacing: FindPeopleLayout.rowSpacing) {
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
                .frame(height: FindPeopleLayout.addButtonHeight)
                .background(added ? OnboardingLabColor.mint : OnboardingLabColor.sunbeam, in: Capsule())
            }
            .buttonStyle(PushPressStyle())
            .disabled(added || model.actingIDs.contains(person.id) || model.isBusy)
            .accessibilityLabel(added ? "Added \(person.name)" : "Add \(person.name)")
        }
        .padding(.vertical, FindPeopleLayout.rowVertical)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle()
                    .fill(OnboardingLabColor.walnut.opacity(FindPeopleLayout.dividerOpacity))
                    .frame(height: 1)
            }
        }
    }

    private func avatar(for person: OnboardingDiscoverPerson) -> some View {
        let initials = String(person.name.prefix(1)).uppercased()
        return ProfilePhotoAvatar(
            imageAssetName: person.imageAssetPath,
            fallbackInitials: initials
        )
        .frame(width: FindPeopleLayout.avatarSize, height: FindPeopleLayout.avatarSize)
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
                .frame(maxWidth: DoneScreenLayout.subtitleMaxWidth)
                .padding(.top, DoneScreenLayout.subtitleTop)
            Spacer(minLength: 0)
            OnboardingCTAButton(title: "Open Push") { model.openApp() }
                .padding(.horizontal, DoneScreenLayout.ctaHorizontal)
                .padding(.bottom, DoneScreenLayout.bottomPadding)
        }
        .padding(.top, DoneScreenLayout.topPadding)
    }
}

// MARK: - Layout

private enum ContactsScreenLayout {
    static let heroTop: CGFloat = 12
    static let heroSize: CGFloat = 96
    static let iconSize: CGFloat = 36
    static let heroFillOpacity = 0.55
    static let heroStrokeOpacity = 0.12
    static let headerTop: CGFloat = 20
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}

private enum FindPeopleLayout {
    static let listTop: CGFloat = 20
    static let errorTop: CGFloat = 10
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
    static let loadingVertical: CGFloat = 40
    static let emptyVertical: CGFloat = 12
    static let rowHorizontal: CGFloat = 16
    static let rowSpacing: CGFloat = 13
    static let rowVertical: CGFloat = 12
    static let avatarSize: CGFloat = 48
    static let addButtonHeight: CGFloat = 36
    static let dividerOpacity = 0.08
}

private enum DoneScreenLayout {
    static let topPadding: CGFloat = 80
    static let subtitleTop: CGFloat = 14
    static let subtitleMaxWidth: CGFloat = 260
    static let ctaHorizontal: CGFloat = 26
    static let bottomPadding: CGFloat = 30
}
