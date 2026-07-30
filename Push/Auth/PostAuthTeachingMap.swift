// Push/Auth/PostAuthTeachingMap.swift
import MapKit
import SwiftUI

/// Satellite teaching map for post-auth location primer.
/// Never requests Core Location (`showsUserLocation` stays false).
/// Signals readiness via `mapViewDidFinishLoadingMap` so the host can
/// reveal a fully painted map instead of grey tiles.
struct PostAuthTeachingMapView: UIViewRepresentable {
    let region: MKCoordinateRegion
    var onMapReady: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMapReady: onMapReady)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.isUserInteractionEnabled = false
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll
        applyStyle(to: mapView)
        context.coordinator.scheduleFallbackReady()
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onMapReady = onMapReady
        // Region is fixed for the teaching map — avoid re-centering on redraws.
    }

    private func applyStyle(to mapView: MKMapView) {
        if #available(iOS 16.0, *) {
            mapView.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
        } else {
            mapView.mapType = .hybrid
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onMapReady: () -> Void
        private var didNotify = false
        private var fallbackTask: Task<Void, Never>?

        init(onMapReady: @escaping () -> Void) {
            self.onMapReady = onMapReady
        }

        deinit {
            fallbackTask?.cancel()
        }

        /// Prefer the MapKit finish-loading callback; fall back so UI never stalls.
        func scheduleFallbackReady() {
            fallbackTask?.cancel()
            fallbackTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: TeachingMapReady.fallbackNanoseconds)
                self?.notifyReady()
            }
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            // Finish-loading often fires before satellite tiles fully paint.
            scheduleSettledReady()
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            // Still reveal — better a partial map than an infinite cream placeholder.
            notifyReady()
        }

        /// Extra beat after MapKit's finish callback so imagery can catch up.
        private func scheduleSettledReady() {
            guard !didNotify else { return }
            fallbackTask?.cancel()
            fallbackTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: TeachingMapReady.settleNanoseconds)
                self?.notifyReady()
            }
        }

        private func notifyReady() {
            guard !didNotify else { return }
            didNotify = true
            fallbackTask?.cancel()
            fallbackTask = nil
            // Delegate may fire off the main actor; SwiftUI state must update on main.
            if Thread.isMainThread {
                onMapReady()
            } else {
                DispatchQueue.main.async { [onMapReady] in
                    onMapReady()
                }
            }
        }
    }
}

private enum TeachingMapReady {
    /// Upper bound if MapKit never signals finish (offline / stalled tiles).
    static let fallbackNanoseconds: UInt64 = 1_800_000_000
    /// After `mapViewDidFinishLoadingMap`, wait before treating the map as paint-ready.
    static let settleNanoseconds: UInt64 = 320_000_000
}
