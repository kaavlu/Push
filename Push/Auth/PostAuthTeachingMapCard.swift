// Push/Auth/PostAuthTeachingMapCard.swift
import MapKit
import SwiftUI

/// Framed satellite teaching map used on location + ghost primers.
/// Hosts SwiftUI overlays (self puck, friend pucks, ghost icon) above MapKit.
struct PostAuthTeachingMapCard<Overlay: View>: View {
    let region: MKCoordinateRegion
    var showMap: Bool
    var showCream: Bool
    var mapBlurRadius: CGFloat = 0
    var onMapReady: () -> Void
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        ZStack {
            PostAuthTeachingMapView(region: region, onMapReady: onMapReady)
                .blur(radius: mapBlurRadius)
                .opacity(showMap ? 1 : 0)

            overlay()

            RoundedRectangle(
                cornerRadius: OnboardingLabMetric.cardCornerRadius,
                style: .continuous
            )
            .fill(OnboardingLabColor.fieldFill)
            .opacity(showCream ? 1 : 0)
            .accessibilityHidden(true)
        }
        .frame(height: PostAuthTeachingMapCardLayout.height)
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
                Color.white.opacity(PostAuthTeachingMapCardLayout.strokeOpacity),
                lineWidth: PostAuthTeachingMapCardLayout.strokeWidth
            )
        )
        .shadow(
            color: OnboardingLabColor.warmShadow.opacity(PostAuthTeachingMapCardLayout.shadowOpacity),
            radius: PostAuthTeachingMapCardLayout.shadowRadius,
            y: PostAuthTeachingMapCardLayout.shadowY
        )
        .allowsHitTesting(false)
    }
}

enum PostAuthTeachingMapCardLayout {
    static let height: CGFloat = 210
    static let strokeOpacity = 0.6
    static let strokeWidth: CGFloat = 0.8
    static let shadowOpacity = 0.12
    static let shadowRadius: CGFloat = 10
    static let shadowY: CGFloat = 6
    static let selfPuckScale: CGFloat = 0.78
}

extension PostAuthTeachingMapCard where Overlay == EmptyView {
    init(
        region: MKCoordinateRegion,
        showMap: Bool,
        showCream: Bool,
        mapBlurRadius: CGFloat = 0,
        onMapReady: @escaping () -> Void
    ) {
        self.region = region
        self.showMap = showMap
        self.showCream = showCream
        self.mapBlurRadius = mapBlurRadius
        self.onMapReady = onMapReady
        self.overlay = { EmptyView() }
    }
}
