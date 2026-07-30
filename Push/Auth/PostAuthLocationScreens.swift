// Push/Auth/PostAuthLocationScreens.swift
import MapKit
import SwiftUI

// MARK: - Location primer

struct PostAuthLocationPrimerScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel
    /// How far the top-down cascade has progressed (title → … → CTA).
    @State private var revealStep: Int = 0
    /// MapKit finished loading (tiles may still settle briefly before reveal).
    @State private var isMapReady = false
    /// Prevents double cascade if map ready fires twice.
    @State private var didContinueAfterMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
            subtitleBlock
                .padding(.top, LocationPrimerLayout.subtitleTop)
            mapSlot
                .padding(.top, LocationPrimerLayout.mapTop)
            bodyCopy
                .padding(.top, LocationPrimerLayout.bodyTop)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .padding(.top, LocationPrimerLayout.errorTop)
                    .opacity(revealStep >= LocationPrimerReveal.cta ? 1 : 0)
            }
            Spacer(minLength: LocationPrimerLayout.ctaSpacerMin)
            OnboardingCTAButton(title: model.isBusy ? "Enabling…" : "Enable location") {
                Task { await model.enableLocation() }
            }
            .disabled(model.isBusy || revealStep < LocationPrimerReveal.cta)
            .opacity(opacity(for: LocationPrimerReveal.cta))
            .offset(y: offset(for: LocationPrimerReveal.cta))
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, LocationPrimerLayout.bottomPadding)
        .animation(PushMotion.contentCrossfade, value: revealStep)
        .animation(PushMotion.contentCrossfade, value: isMapReady)
        .task {
            // Profile puck + fixed SF only — never requests location authorization.
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
            .opacity(opacity(for: LocationPrimerReveal.title))
            .offset(y: offset(for: LocationPrimerReveal.title))
    }

    private var subtitleBlock: some View {
        Text("A private live map for real friends — not a tracker.")
            .font(OnboardingLabFont.text(16, .medium))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(opacity(for: LocationPrimerReveal.subtitle))
            .offset(y: offset(for: LocationPrimerReveal.subtitle))
    }

    private var bodyCopy: some View {
        Text(LocationPrimerCopy.locationBody)
            .font(OnboardingLabFont.text(15, .medium))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(opacity(for: LocationPrimerReveal.body))
            .offset(y: offset(for: LocationPrimerReveal.body))
    }

    /// Reserved-height card: cream fades in while MapKit warms; map crossfades when paint-ready.
    private var mapSlot: some View {
        let showCard = revealStep >= LocationPrimerReveal.mapCard
        let showMap = revealStep >= LocationPrimerReveal.mapPainted && isMapReady
        return ZStack {
            // Always mounted so tiles load during title/subtitle cascade.
            PostAuthTeachingMapView(region: teachingRegion) {
                guard !isMapReady else { return }
                isMapReady = true
            }
            .opacity(showMap ? 1 : 0)

            if showMap, let puck = model.selfPuck {
                SelfPuckView(data: puck)
                    .scaleEffect(LocationPrimerLayout.puckScale)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            RoundedRectangle(
                cornerRadius: OnboardingLabMetric.cardCornerRadius,
                style: .continuous
            )
            .fill(OnboardingLabColor.fieldFill)
            .opacity(showCard && !showMap ? 1 : 0)
            .accessibilityHidden(true)
        }
        .frame(height: LocationPrimerLayout.mapHeight)
        .clipShape(
            RoundedRectangle(
                cornerRadius: OnboardingLabMetric.cardCornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: OnboardingLabMetric.cardCornerRadius,
                style: .continuous
            )
            .stroke(
                Color.white.opacity(LocationPrimerLayout.mapStrokeOpacity),
                lineWidth: LocationPrimerLayout.mapStrokeWidth
            )
        )
        .shadow(
            color: OnboardingLabColor.warmShadow.opacity(LocationPrimerLayout.mapShadowOpacity),
            radius: LocationPrimerLayout.mapShadowRadius,
            y: LocationPrimerLayout.mapShadowY
        )
        .opacity(showCard ? 1 : 0)
        .offset(y: showCard ? 0 : LocationPrimerLayout.revealOffsetY)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map preview of you in San Francisco")
    }

    // MARK: Cascade

    /// Title → subtitle → cream map card, then paint map when ready.
    private func runOpeningCascade() async {
        await stepTo(LocationPrimerReveal.title)
        try? await Task.sleep(nanoseconds: LocationPrimerReveal.staggerNanoseconds)
        await stepTo(LocationPrimerReveal.subtitle)
        try? await Task.sleep(nanoseconds: LocationPrimerReveal.staggerNanoseconds)
        // Cream card fades in so the page feels complete while MapKit finishes.
        await stepTo(LocationPrimerReveal.mapCard)
        if isMapReady {
            await continueCascadeAfterMapReady()
        }
    }

    private func continueCascadeAfterMapReady() async {
        guard !didContinueAfterMap else { return }
        didContinueAfterMap = true
        // Host-side settle pairs with teaching-map settle so tiles are painted.
        try? await Task.sleep(nanoseconds: LocationPrimerReveal.mapSettleNanoseconds)
        await stepTo(LocationPrimerReveal.mapPainted)
        try? await Task.sleep(nanoseconds: LocationPrimerReveal.staggerNanoseconds)
        await stepTo(LocationPrimerReveal.body)
        try? await Task.sleep(nanoseconds: LocationPrimerReveal.staggerNanoseconds)
        await stepTo(LocationPrimerReveal.cta)
    }

    @MainActor
    private func stepTo(_ step: Int) async {
        withAnimation(PushMotion.contentCrossfade) {
            revealStep = max(revealStep, step)
        }
    }

    private func opacity(for step: Int) -> Double {
        revealStep >= step ? 1 : 0
    }

    private func offset(for step: Int) -> CGFloat {
        revealStep >= step ? 0 : LocationPrimerLayout.revealOffsetY
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            blockedHero
                .frame(maxWidth: .infinity)
                .padding(.top, LocationBlockedLayout.heroTop)
            OnboardingHeader(
                title: "Location is required.",
                subtitle: "Push is built around live presence. Enable Location in Settings to continue.",
                alignment: .center
            )
            .padding(.top, LocationBlockedLayout.headerTop)
            if let error = model.errorMessage {
                Text(error)
                    .font(OnboardingLabFont.text(14, .medium))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, LocationBlockedLayout.errorTop)
            }
            Spacer(minLength: LocationBlockedLayout.ctaSpacerMin)
            OnboardingCTAButton(title: "Open Settings") {
                model.openSystemSettings()
            }
            .disabled(model.isBusy)
            OnboardingTextButton(title: model.isBusy ? "Checking…" : "Try again") {
                Task { await model.retryLocationAccess() }
            }
            .disabled(model.isBusy)
            if signOut.isAvailable {
                OnboardingTextButton(title: "Sign out") {
                    Task { await signOut() }
                }
                .disabled(model.isBusy)
            }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, LocationBlockedLayout.bottomPadding)
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
}

// MARK: - Layout

private enum LocationPrimerCopy {
    /// Body under the teaching map — location value without a second header stack.
    static let locationBody =
        "Location is how you know what your real friends are up to — who's free, what's forming — without the group chat."
}

/// Cascade steps for top-down fade-in (higher = later).
private enum LocationPrimerReveal {
    static let title = 1
    static let subtitle = 2
    /// Cream card visible; MapKit still warming underneath.
    static let mapCard = 3
    /// Satellite map + self puck crossfade over cream.
    static let mapPainted = 4
    static let body = 5
    static let cta = 6
    /// Delay between cascade steps.
    static let staggerNanoseconds: UInt64 = 140_000_000
    /// After MapKit reports ready, wait so tiles finish painting before map fade.
    static let mapSettleNanoseconds: UInt64 = 200_000_000
}

private enum LocationPrimerLayout {
    static let mapHeight: CGFloat = 210
    static let puckScale: CGFloat = 0.78
    static let subtitleTop: CGFloat = 8
    static let mapTop: CGFloat = 20
    static let bodyTop: CGFloat = 16
    static let errorTop: CGFloat = 12
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
    static let revealOffsetY: CGFloat = 10
    static let mapStrokeOpacity = 0.6
    static let mapStrokeWidth: CGFloat = 0.8
    static let mapShadowOpacity = 0.12
    static let mapShadowRadius: CGFloat = 10
    static let mapShadowY: CGFloat = 6
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
