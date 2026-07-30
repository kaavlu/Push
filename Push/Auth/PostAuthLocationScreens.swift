// Push/Auth/PostAuthLocationScreens.swift
import MapKit
import SwiftUI

// MARK: - Location primer

struct PostAuthLocationPrimerScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel
    @State private var isMapReady = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title/subtitle paint immediately — map warms underneath.
            OnboardingHeader(
                title: "Know the move.",
                subtitle: "A private live map for real friends — not a tracker."
            )
            mapSlot
                .padding(.top, LocationPrimerLayout.mapTop)

            if isMapReady {
                bodyAndActions
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, LocationPrimerLayout.bottomPadding)
        .animation(PushMotion.contentCrossfade, value: isMapReady)
        .task {
            // Fixed SF coords only — never requests location authorization.
            await model.loadSelfPuckPreview()
        }
    }

    /// Reserved-height slot: cream placeholder while MapKit tiles finish loading.
    private var mapSlot: some View {
        ZStack {
            // Always mount so MapKit starts loading as early as possible.
            PostAuthTeachingMapView(region: teachingRegion) {
                guard !isMapReady else { return }
                isMapReady = true
            }
            .opacity(isMapReady ? 1 : 0)

            if isMapReady, let puck = model.selfPuck {
                SelfPuckView(data: puck)
                    .scaleEffect(LocationPrimerLayout.puckScale)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if !isMapReady {
                RoundedRectangle(
                    cornerRadius: OnboardingLabMetric.cardCornerRadius,
                    style: .continuous
                )
                .fill(OnboardingLabColor.fieldFill)
                .accessibilityHidden(true)
            }
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
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Map preview of you in San Francisco")
    }

    @ViewBuilder
    private var bodyAndActions: some View {
        Text(LocationPrimerCopy.locationBody)
            .font(OnboardingLabFont.text(15, .medium))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, LocationPrimerLayout.bodyTop)
        if let error = model.errorMessage {
            Text(error)
                .font(OnboardingLabFont.text(14, .medium))
                .foregroundStyle(.red)
                .padding(.top, LocationPrimerLayout.errorTop)
        }
        Spacer(minLength: LocationPrimerLayout.ctaSpacerMin)
        OnboardingCTAButton(title: model.isBusy ? "Enabling…" : "Enable location") {
            Task { await model.enableLocation() }
        }
        .disabled(model.isBusy)
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

private enum LocationPrimerLayout {
    static let mapHeight: CGFloat = 210
    static let puckScale: CGFloat = 0.78
    static let mapTop: CGFloat = 20
    static let bodyTop: CGFloat = 16
    static let errorTop: CGFloat = 12
    static let ctaSpacerMin: CGFloat = 22
    static let bottomPadding: CGFloat = 26
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
