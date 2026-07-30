// Push/Auth/PostAuthGhostScreen.swift
import MapKit
import SwiftUI

/// Ghost teach: map + self puck → self vanishes while map blurs and eye.slash centers.
struct PostAuthGhostScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    @State private var revealStep = 0
    @State private var isMapReady = false
    @State private var showSelfPuck = true
    @State private var mapBlur: CGFloat = 0
    @State private var showGhostIcon = false
    @State private var didRunSequence = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            mapSlot
                .padding(.top, GhostScreenLayout.mapTop)
                .onboardingCascadeVisible(revealStep >= GhostReveal.map)
            subtitleBlock
                .padding(.top, GhostScreenLayout.subtitleTop)
            Spacer(minLength: GhostScreenLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Continue") {
                model.continueFromGhost()
            }
            .disabled(model.isBusy || revealStep < GhostReveal.cta)
            .onboardingCascadeVisible(revealStep >= GhostReveal.cta)
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, GhostScreenLayout.bottomPadding)
        .animation(OnboardingCascadeTiming.laterCascade, value: revealStep)
        .animation(OnboardingCascadeTiming.laterCascade, value: showSelfPuck)
        .animation(OnboardingCascadeTiming.laterCascade, value: showGhostIcon)
        .animation(OnboardingCascadeTiming.laterCascade, value: mapBlur)
        .task {
            await model.loadSelfPuckPreview()
            if model.hasFullyRevealed(.ghost) {
                applyInstantCompleteState()
                return
            }
            await runSequence()
        }
        .onChange(of: isMapReady) { ready in
            guard ready, !model.hasFullyRevealed(.ghost) else { return }
            Task { await continueAfterMapReady() }
        }
    }

    private var titleBlock: some View {
        Text("Go Invisible at any time.")
            .font(OnboardingLabFont.rounded(30, .heavy))
            .foregroundStyle(OnboardingLabColor.espresso)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCascadeVisible(revealStep >= GhostReveal.title)
    }

    private var subtitleBlock: some View {
        Text(GhostScreenCopy.subtitle)
            .font(OnboardingLabFont.text(16, .medium))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCascadeVisible(revealStep >= GhostReveal.ghostMoment)
    }

    private var mapSlot: some View {
        let showMap = revealStep >= GhostReveal.mapPainted && isMapReady
        let showCream = revealStep >= GhostReveal.map && !showMap
        return PostAuthTeachingMapCard(
            region: teachingRegion,
            showMap: showMap,
            showCream: showCream,
            mapBlurRadius: mapBlur,
            onMapReady: {
                guard !isMapReady else { return }
                isMapReady = true
            }
        ) {
            if showMap, showSelfPuck, let puck = model.selfPuck {
                SelfPuckView(data: puck)
                    .scaleEffect(PostAuthTeachingMapCardLayout.selfPuckScale)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            if showMap, showGhostIcon {
                ghostIcon
                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map preview showing Ghost mode")
    }

    private var ghostIcon: some View {
        Image(systemName: "eye.slash.fill")
            .font(.system(size: GhostScreenLayout.ghostIconSize, weight: .semibold))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: GhostScreenLayout.ghostWell, height: GhostScreenLayout.ghostWell)
            .background(
                Circle()
                    .fill(OnboardingLabColor.fieldFill.opacity(0.92))
                    .shadow(color: OnboardingLabColor.warmShadow.opacity(0.2), radius: 10, y: 6)
            )
            .overlay(
                Circle()
                    .stroke(OnboardingLabColor.walnut.opacity(0.14), lineWidth: 1)
            )
    }

    // MARK: Sequence

    private func runSequence() async {
        OnboardingCascadeRunner.step(&revealStep, to: GhostReveal.title, laterScreen: true)
        await OnboardingCascadeRunner.sleepStagger(laterScreen: true)
        OnboardingCascadeRunner.step(&revealStep, to: GhostReveal.map, laterScreen: true)
        if isMapReady {
            await continueAfterMapReady()
        }
    }

    private func continueAfterMapReady() async {
        guard !didRunSequence else { return }
        didRunSequence = true
        try? await Task.sleep(nanoseconds: GhostReveal.mapSettleNanoseconds)
        OnboardingCascadeRunner.step(&revealStep, to: GhostReveal.mapPainted, laterScreen: true)
        // Hold on the clear self-puck map so the vanish reads clearly.
        await OnboardingCascadeRunner.sleepBeat(laterScreen: true)
        await OnboardingCascadeRunner.sleepBeat(laterScreen: true)
        // Vanish self + blur map + center eye + subtitle together.
        withAnimation(OnboardingCascadeTiming.laterCascade) {
            showSelfPuck = false
            mapBlur = GhostScreenLayout.mapBlurRadius
            showGhostIcon = true
            revealStep = max(revealStep, GhostReveal.ghostMoment)
        }
        await OnboardingCascadeRunner.sleepStagger(laterScreen: true)
        await OnboardingCascadeRunner.sleepBeat(laterScreen: true)
        OnboardingCascadeRunner.step(&revealStep, to: GhostReveal.cta, laterScreen: true)
        model.markFullyRevealed(.ghost)
    }

    /// Back navigation: end-state map (blurred + ghost icon), no sequence.
    private func applyInstantCompleteState() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isMapReady = true
            didRunSequence = true
            showSelfPuck = false
            mapBlur = GhostScreenLayout.mapBlurRadius
            showGhostIcon = true
            revealStep = GhostReveal.cta
        }
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

// MARK: - Layout / copy

private enum GhostScreenCopy {
    static let subtitle =
        "Ghost hides you from friends while you keep using Push. Turn it on anytime in Profile — you're visible by default."
}

private enum GhostReveal {
    static let title = 1
    static let map = 2
    static let mapPainted = 3
    static let ghostMoment = 4
    static let cta = 5
    static let mapSettleNanoseconds: UInt64 = 550_000_000
}

private enum GhostScreenLayout {
    static let mapTop: CGFloat = 20
    static let subtitleTop: CGFloat = 16
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
    static let mapBlurRadius: CGFloat = 8
    static let ghostIconSize: CGFloat = 34
    static let ghostWell: CGFloat = 72
}
