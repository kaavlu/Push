// Push/Auth/PostAuthConnectScreens.swift
import SwiftUI

// MARK: - Find people (soft nudge; contacts matched on appear)

struct PostAuthFindPeopleScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var revealStep = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Add people on Push.",
                subtitle: "Friends from your contacts who are already here — continue even if you add no one."
            )
            .onboardingCascadeVisible(revealStep >= 1)
            content
                .padding(.top, FindPeopleLayout.listTop)
                .onboardingCascadeVisible(revealStep >= 2)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, FindPeopleLayout.errorTop)
                    .onboardingCascadeVisible(revealStep >= 2)
            }
            Spacer(minLength: FindPeopleLayout.ctaSpacerMin)
            OnboardingCTAButton(title: model.isBusy ? "Finishing…" : model.findPeopleCTALabel) {
                Task { await model.continueFromFindPeople() }
            }
            .disabled(model.isBusy || model.isLoadingPeople || revealStep < 3)
            .onboardingCascadeVisible(revealStep >= 3)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, FindPeopleLayout.bottomPadding)
        .animation(OnboardingCascadeTiming.laterCascade, value: revealStep)
        .task {
            await model.loadFindPeopleDirectoryIfNeeded()
            await runCascade()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingPeople {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, FindPeopleLayout.loadingVertical)
        } else if model.people.isEmpty {
            Text("No matches yet — you can add friends anytime from the app.")
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

    private func runCascade() async {
        if model.hasFullyRevealed(.findPeople) {
            OnboardingCascadeRunner.revealInstantly(&revealStep, to: 3)
            return
        }
        for step in 1...3 {
            OnboardingCascadeRunner.step(&revealStep, to: step, laterScreen: true)
            await OnboardingCascadeRunner.sleepStagger(laterScreen: true)
        }
        model.markFullyRevealed(.findPeople)
    }
}

// MARK: - Done

struct PostAuthDoneScreen: View {
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var revealStep = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("You're in.")
                .font(OnboardingLabFont.rounded(52, .heavy))
                .foregroundStyle(OnboardingLabColor.espresso)
                .onboardingCascadeVisible(revealStep >= 1)
            Text("Push works best with your real friends. They're waiting on the map.")
                .font(OnboardingLabFont.text(17, .medium))
                .foregroundStyle(OnboardingLabColor.walnut)
                .multilineTextAlignment(.center)
                .frame(maxWidth: DoneScreenLayout.subtitleMaxWidth)
                .padding(.top, DoneScreenLayout.subtitleTop)
                .onboardingCascadeVisible(revealStep >= 2)
            Spacer(minLength: 0)
            OnboardingCTAButton(title: "Open Push") { model.openApp() }
                .padding(.horizontal, DoneScreenLayout.ctaHorizontal)
                .padding(.bottom, DoneScreenLayout.bottomPadding)
                .onboardingCascadeVisible(revealStep >= 3)
        }
        .padding(.top, DoneScreenLayout.topPadding)
        .animation(OnboardingCascadeTiming.laterCascade, value: revealStep)
        .task { await runCascade() }
    }

    private func runCascade() async {
        if model.hasFullyRevealed(.done) {
            OnboardingCascadeRunner.revealInstantly(&revealStep, to: 3)
            return
        }
        for step in 1...3 {
            OnboardingCascadeRunner.step(&revealStep, to: step, laterScreen: true)
            await OnboardingCascadeRunner.sleepStagger(laterScreen: true)
        }
        model.markFullyRevealed(.done)
    }
}

// MARK: - Layout

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
