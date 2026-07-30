// Push/Auth/PostAuthLocationScreens.swift
import MapKit
import SwiftUI

// MARK: - Location primer

struct PostAuthLocationPrimerScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var revealStep: Int = 0
    @State private var isMapReady = false
    @State private var didContinueAfterMap = false
    /// How many fixture friend pucks have popped (0…3).
    @State private var friendPopCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            subtitleBlock
                .padding(.top, LocationPrimerLayout.subtitleTop)
            mapSlot
                .padding(.top, LocationPrimerLayout.mapTop)
                .onboardingCascadeVisible(revealStep >= LocationPrimerReveal.mapCard)
            bodyCopy
                .padding(.top, LocationPrimerLayout.bodyTop)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, LocationPrimerLayout.errorTop)
                    .onboardingCascadeVisible(revealStep >= LocationPrimerReveal.cta)
            }
            Spacer(minLength: LocationPrimerLayout.ctaSpacerMin)
            OnboardingCTAButton(title: model.isBusy ? "Enabling…" : "Enable location") {
                Task { await model.enableLocation() }
            }
            .disabled(model.isBusy || revealStep < LocationPrimerReveal.cta)
            .onboardingCascadeVisible(revealStep >= LocationPrimerReveal.cta)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, LocationPrimerLayout.bottomPadding)
        .animation(OnboardingCascadeTiming.cascade, value: revealStep)
        .animation(OnboardingCascadeTiming.friendPop, value: friendPopCount)
        .animation(OnboardingCascadeTiming.cascade, value: isMapReady)
        .task {
            await model.loadSelfPuckPreview()
            await runOpeningCascade()
        }
        .onChange(of: isMapReady) { ready in
            guard ready else { return }
            Task { await continueCascadeAfterMapReady() }
        }
    }

    private var titleBlock: some View {
        Text("Know the move.")
            .font(OnboardingLabFont.rounded(30, .heavy))
            .foregroundStyle(OnboardingLabColor.espresso)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCascadeVisible(revealStep >= LocationPrimerReveal.title)
    }

    private var subtitleBlock: some View {
        Text("A private live map for real friends — not a tracker.")
            .font(OnboardingLabFont.text(16, .medium))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCascadeVisible(revealStep >= LocationPrimerReveal.subtitle)
    }

    private var bodyCopy: some View {
        Text(LocationPrimerCopy.locationBody)
            .font(OnboardingLabFont.text(15, .medium))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .onboardingCascadeVisible(revealStep >= LocationPrimerReveal.body)
    }

    private var mapSlot: some View {
        let showMap = revealStep >= LocationPrimerReveal.mapPainted && isMapReady
        let showCream = revealStep >= LocationPrimerReveal.mapCard && !showMap
        return PostAuthTeachingMapCard(
            region: teachingRegion,
            showMap: showMap,
            showCream: showCream,
            onMapReady: {
                guard !isMapReady else { return }
                isMapReady = true
            }
        ) {
            if showMap, let puck = model.selfPuck {
                SelfPuckView(data: puck)
                    .scaleEffect(PostAuthTeachingMapCardLayout.selfPuckScale)
                    .allowsHitTesting(false)
            }
            ForEach(Array(PostAuthTeachFriendFixture.all.enumerated()), id: \.element.id) { index, friend in
                OnboardingAvatar(
                    assetName: friend.assetName,
                    size: friend.size,
                    ring: friend.ring,
                    ringWidth: 2.5
                )
                .offset(friend.offset)
                .onboardingFriendPopVisible(friendPopCount > index)
                .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map preview of you and friends in San Francisco")
    }

    // MARK: Cascade

    private func runOpeningCascade() async {
        await stepTo(LocationPrimerReveal.title)
        await OnboardingCascadeRunner.sleepStagger()
        await stepTo(LocationPrimerReveal.subtitle)
        await OnboardingCascadeRunner.sleepStagger()
        await stepTo(LocationPrimerReveal.mapCard)
        if isMapReady {
            await continueCascadeAfterMapReady()
        }
    }

    private func continueCascadeAfterMapReady() async {
        guard !didContinueAfterMap else { return }
        didContinueAfterMap = true
        try? await Task.sleep(nanoseconds: LocationPrimerReveal.mapSettleNanoseconds)
        await stepTo(LocationPrimerReveal.mapPainted)
        await OnboardingCascadeRunner.sleepStagger()
        await stepTo(LocationPrimerReveal.body)
        await OnboardingCascadeRunner.sleepBeat()
        // Friend pucks pop 1-by-1 around self after body copy lands.
        for count in 1...PostAuthTeachFriendFixture.all.count {
            withAnimation(OnboardingCascadeTiming.friendPop) {
                friendPopCount = count
            }
            await OnboardingCascadeRunner.sleepFriendPop()
        }
        await OnboardingCascadeRunner.sleepStagger()
        await stepTo(LocationPrimerReveal.cta)
    }

    @MainActor
    private func stepTo(_ step: Int) async {
        OnboardingCascadeRunner.step(&revealStep, to: step)
    }

    private var teachingRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: OnboardingMapDefaults.center,
            span: MKCoordinateSpan(
                latitudeDelta: OnboardingMapDefaults.latitudeDelta,
                longitudeDelta: OnboardingMapDefaults.longitudeDelta
            )
        )
    }
}

// MARK: - Location blocked

struct PostAuthLocationBlockedScreen: View {
    @Environment(\.pushLayout) private var layout
    @Environment(\.signOut) private var signOut
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var revealStep = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            blockedHero
                .frame(maxWidth: .infinity)
                .padding(.top, LocationBlockedLayout.heroTop)
                .onboardingCascadeVisible(revealStep >= 1)
            OnboardingHeader(
                title: "Location is required.",
                subtitle: "Push is built around live presence. Enable Location in Settings to continue.",
                alignment: .center
            )
            .padding(.top, LocationBlockedLayout.headerTop)
            .onboardingCascadeVisible(revealStep >= 2)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, LocationBlockedLayout.errorTop)
                    .onboardingCascadeVisible(revealStep >= 3)
            }
            Spacer(minLength: LocationBlockedLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Open Settings") {
                model.openSystemSettings()
            }
            .disabled(model.isBusy)
            .onboardingCascadeVisible(revealStep >= 3)
            OnboardingTextButton(title: model.isBusy ? "Checking…" : "Try again") {
                Task { await model.retryLocationAccess() }
            }
            .disabled(model.isBusy)
            .onboardingCascadeVisible(revealStep >= 4)
            if signOut.isAvailable {
                OnboardingTextButton(title: "Sign out") {
                    Task { await signOut() }
                }
                .disabled(model.isBusy)
                .onboardingCascadeVisible(revealStep >= 5)
            }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, LocationBlockedLayout.bottomPadding)
        .animation(OnboardingCascadeTiming.cascade, value: revealStep)
        .task { await runCascade() }
    }

    private var blockedHero: some View {
        Image(systemName: "location.slash.fill")
            .font(.system(size: LocationBlockedLayout.iconSize, weight: .semibold))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: LocationBlockedLayout.heroSize, height: LocationBlockedLayout.heroSize)
            .background(
                Circle()
                    .fill(OnboardingLabColor.walnut.opacity(LocationBlockedLayout.heroFillOpacity))
            )
            .overlay(
                Circle()
                    .stroke(OnboardingLabColor.walnut.opacity(LocationBlockedLayout.heroStrokeOpacity), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private func runCascade() async {
        for step in 1...5 {
            OnboardingCascadeRunner.step(&revealStep, to: step)
            await OnboardingCascadeRunner.sleepStagger()
        }
    }
}

// MARK: - Layout

private enum LocationPrimerCopy {
    static let locationBody =
        "Location is how you know what your real friends are up to — who's free, what's forming — without the group chat."
}

private enum LocationPrimerReveal {
    static let title = 1
    static let subtitle = 2
    static let mapCard = 3
    static let mapPainted = 4
    static let body = 5
    static let cta = 6
    static let mapSettleNanoseconds: UInt64 = 400_000_000
}

private enum LocationPrimerLayout {
    static let subtitleTop: CGFloat = 8
    static let mapTop: CGFloat = 20
    static let bodyTop: CGFloat = 16
    static let errorTop: CGFloat = 12
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}

private enum LocationBlockedLayout {
    static let heroTop: CGFloat = 12
    static let heroSize: CGFloat = 96
    static let iconSize: CGFloat = 36
    static let heroFillOpacity = 0.08
    static let heroStrokeOpacity = 0.12
    static let headerTop: CGFloat = 20
    static let errorTop: CGFloat = 12
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
}
