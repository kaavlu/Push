//
//  MapKitPlaceResolver.swift
//  Push
//
//  Issue #101 (I3) — production PlaceResolving via MapKit POI search +
//  reverse-geocode fallback. MapKit / CoreLocation stay in this file only.
//

import CoreLocation
import Foundation
import MapKit

/// Live place resolver: nearby points of interest around a dwell centroid.
/// Ranking is pure (`PlaceCandidateRanker`); this type only fetches.
final class MapKitPlaceResolver: PlaceResolving, @unchecked Sendable {
    private let searchRadiusMeters: Double
    private let includeReverseGeocodeFallback: Bool

    init(
        searchRadiusMeters: Double = PlaceResolutionConfiguration.searchRadiusMeters,
        includeReverseGeocodeFallback: Bool = true
    ) {
        self.searchRadiusMeters = searchRadiusMeters
        self.includeReverseGeocodeFallback = includeReverseGeocodeFallback
    }

    func resolve(_ request: PlaceResolutionRequest) async throws -> PlaceResolutionOutcome {
        let payload = try await search(request)
        return PlaceCandidateRanker.rank(request: request, payload: payload)
    }

    // MARK: - Search

    private func search(_ request: PlaceResolutionRequest) async throws -> PlaceSearchPayload {
        let center = CLLocationCoordinate2D(
            latitude: request.centroidLatitude,
            longitude: request.centroidLongitude
        )
        guard CLLocationCoordinate2DIsValid(center) else {
            return PlaceSearchPayload()
        }

        let poiCandidates = try await fetchPointsOfInterest(center: center)
        let fallback: GeographicPlaceContext?
        if poiCandidates.isEmpty, includeReverseGeocodeFallback {
            fallback = await reverseGeocode(center: center)
        } else if includeReverseGeocodeFallback {
            // Keep reverse-geocode available when ranking may still yield ambiguous/empty.
            fallback = await reverseGeocode(center: center)
        } else {
            fallback = nil
        }

        return PlaceSearchPayload(candidates: poiCandidates, geographicFallback: fallback)
    }

    private func fetchPointsOfInterest(
        center: CLLocationCoordinate2D
    ) async throws -> [UnrankedPlaceCandidate] {
        let poiRequest = MKLocalPointsOfInterestRequest(
            center: center,
            radius: searchRadiusMeters
        )
        poiRequest.pointOfInterestFilter = .includingAll
        let search = MKLocalSearch(request: poiRequest)
        let response: MKLocalSearch.Response
        do {
            response = try await search.start()
        } catch {
            throw PlaceResolutionError.providerFailed
        }

        return response.mapItems.compactMap { item in
            mapItemToCandidate(item)
        }
    }

    private func mapItemToCandidate(_ item: MKMapItem) -> UnrankedPlaceCandidate? {
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else { return nil }

        let coordinate = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }

        // Prefer MapKit's stable identifier when the OS provides it (iOS 18+).
        let id: String
        if #available(iOS 18.0, *) {
            if let identifier = item.identifier?.rawValue, !identifier.isEmpty {
                id = identifier
            } else {
                id = syntheticPlaceID(name: name, coordinate: coordinate)
            }
        } else {
            id = syntheticPlaceID(name: name, coordinate: coordinate)
        }

        let category = item.pointOfInterestCategory?.rawValue

        return UnrankedPlaceCandidate(
            id: id,
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: category
        )
    }

    private func syntheticPlaceID(
        name: String,
        coordinate: CLLocationCoordinate2D
    ) -> String {
        let lat = Int((coordinate.latitude * 1e5).rounded())
        let lon = Int((coordinate.longitude * 1e5).rounded())
        return "mk-\(name.lowercased())-\(lat)-\(lon)"
    }

    private func reverseGeocode(
        center: CLLocationCoordinate2D
    ) async -> GeographicPlaceContext? {
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let geocoder = CLGeocoder()
        do {
            let marks = try await geocoder.reverseGeocodeLocation(location)
            guard let mark = marks.first else { return nil }
            return geographicContext(from: mark)
        } catch {
            return nil
        }
    }

    private func geographicContext(from mark: CLPlacemark) -> GeographicPlaceContext? {
        let locality = mark.locality ?? mark.subLocality
        let thoroughfare = mark.thoroughfare
        let area = mark.administrativeArea

        let display: String?
        if let sub = mark.subLocality, !sub.isEmpty {
            display = sub
        } else if let locality, !locality.isEmpty {
            display = locality
        } else if let thoroughfare, !thoroughfare.isEmpty {
            display = thoroughfare
        } else if let area, !area.isEmpty {
            display = area
        } else {
            display = nil
        }

        guard let displayName = display else { return nil }
        return GeographicPlaceContext(
            displayName: displayName,
            locality: locality,
            thoroughfare: thoroughfare,
            administrativeArea: area
        )
    }
}
