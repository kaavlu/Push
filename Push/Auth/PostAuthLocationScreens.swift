// Push/Auth/PostAuthLocationScreens.swift
import MapKit
import SwiftUI

// MARK: - Location primer

struct PostAuthLocationPrimerScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: PostAuthOnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            teachingMap
            OnboardingHeader(
                title: "Push runs on location.",
                subtitle: "It's how you see what your real friends are up to — who's free, what's forming — without the group chat."
            )
            .padding(.top, LocationPrimerLayout.headerTop)
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
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, LocationPrimerLayout.bottomPadding)
        .task {
            await model.loadSelfPuckPreview()
        }
    }

    private var teachingMap: some View {
        // iOS 16 Map API — deployment target is 16.4 (not MapCameraPosition / Annotation).
        Map(
            coordinateRegion: .constant(teachingRegion),
            interactionModes: [],
            showsUserLocation: false,
            annotationItems: selfPuckAnnotations
        ) { item in
            MapAnnotation(coordinate: item.coordinate) {
                SelfPuckView(data: item.data)
                    .scaleEffect(LocationPrimerLayout.puckScale)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: LocationPrimerLayout.mapHeight)
        .clipShape(RoundedRectangle(cornerRadius: OnboardingLabMetric.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingLabMetric.cardCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(LocationPrimerLayout.mapStrokeOpacity), lineWidth: LocationPrimerLayout.mapStrokeWidth)
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

    private var teachingRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: OnboardingMapDefaults.center,
            span: MKCoordinateSpan(
                latitudeDelta: OnboardingMapDefaults.latitudeDelta,
                longitudeDelta: OnboardingMapDefaults.longitudeDelta
            )
        )
    }

    private var selfPuckAnnotations: [LocationPrimerPuckAnnotation] {
        guard let puck = model.selfPuck else { return [] }
        return [LocationPrimerPuckAnnotation(data: puck)]
    }
}

/// Identifiable wrapper for Map annotationItems (iOS 16 Map API).
private struct LocationPrimerPuckAnnotation: Identifiable {
    let data: SelfPuckData
    var id: String { data.id }
    var coordinate: CLLocationCoordinate2D { data.coordinate }
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

private enum LocationPrimerLayout {
    static let mapHeight: CGFloat = 210
    static let puckScale: CGFloat = 0.78
    static let headerTop: CGFloat = 24
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
