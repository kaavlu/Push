//
//  LocationSession+PlaceResolution.swift
//  Push
//
//  Issue #101 (I3) / #105 — schedule place resolution for confirmed dwells
//  and republish presence when place context attaches or clears.
//

import Foundation

@MainActor
extension LocationSession {
    /// React to dwell lifecycle: resolve on arrival / centroid change / retry;
    /// clear + republish on departure. Never blocks the publish path.
    func handleDwellPlaceResolution(
        _ dwell: DwellDetectionState,
        at evaluationTime: Date
    ) {
        if dwell.transition == .departed {
            clearPlaceResolutionContext(cancelTask: true)
            // Drop At {place} / Chilling without waiting on movement throttle.
            // (.departed only fires after a confirmed dwell.)
            republishPresenceAfterPlaceContextChange()
            return
        }

        guard dwell.phase == .dwelling, let session = dwell.activeSession else {
            return
        }

        if dwell.transition == .arrived {
            placeResolveAttemptsForCurrentDwell = 0
            lastPlaceLookupDwellSessionID = nil
            lastPlaceLookupCentroidLatitude = nil
            lastPlaceLookupCentroidLongitude = nil
            pendingPlaceResolutionRetry = false
            activePlaceResolution = nil
            schedulePlaceResolution(for: session, at: evaluationTime)
            // First dwell confirmation → Chilling until (if) place resolves.
            republishPresenceAfterPlaceContextChange()
            return
        }

        guard shouldResolvePlace(for: session) else { return }
        schedulePlaceResolution(for: session, at: evaluationTime)
    }

    func shouldResolvePlace(for session: DwellLifecycleSession) -> Bool {
        if placeResolveAttemptsForCurrentDwell
            >= PlaceResolutionConfiguration.maxResolveAttemptsPerDwell
        {
            return false
        }

        // New dwell session (should be rare without .arrived, but safe).
        if lastPlaceLookupDwellSessionID != session.id {
            return true
        }

        // Centroid moved enough to warrant a fresh search.
        if let lat = lastPlaceLookupCentroidLatitude,
           let lon = lastPlaceLookupCentroidLongitude
        {
            let moved = GeoDistance.meters(
                fromLatitude: lat,
                longitude: lon,
                toLatitude: session.centroidLatitude,
                longitude: session.centroidLongitude
            )
            if moved >= PlaceResolutionConfiguration.centroidChangeReresolveMeters {
                return true
            }
        }

        // One-shot retry after a provider failure (not every subsequent fix).
        if pendingPlaceResolutionRetry {
            return true
        }

        return false
    }

    func schedulePlaceResolution(
        for session: DwellLifecycleSession,
        at evaluationTime: Date
    ) {
        guard !isShutDown else { return }
        guard placeResolveAttemptsForCurrentDwell
            < PlaceResolutionConfiguration.maxResolveAttemptsPerDwell
        else { return }

        placeResolveAttemptsForCurrentDwell += 1
        pendingPlaceResolutionRetry = false
        lastPlaceLookupDwellSessionID = session.id
        lastPlaceLookupCentroidLatitude = session.centroidLatitude
        lastPlaceLookupCentroidLongitude = session.centroidLongitude

        let request = PlaceResolutionRequest(
            session: session,
            previousResolvedPlaceID: lastConfidentPlaceID,
            evaluationTime: evaluationTime
        )
        let resolver = placeResolver
        let expectedDwellID = session.id

        placeResolutionTask?.cancel()
        placeResolutionTask = Task { [weak self] in
            do {
                let outcome = try await resolver.resolve(request)
                await self?.applyPlaceResolution(
                    outcome,
                    expectedDwellSessionID: expectedDwellID
                )
            } catch is CancellationError {
                return
            } catch {
                // Failures leave presence publishing unchanged; re-arm a single retry.
                await self?.recordPlaceResolutionFailure(
                    expectedDwellSessionID: expectedDwellID
                )
            }
        }
    }

    func applyPlaceResolution(
        _ outcome: PlaceResolutionOutcome,
        expectedDwellSessionID: String
    ) {
        guard !isShutDown else { return }
        guard dwellState.activeSession?.id == expectedDwellSessionID else { return }
        pendingPlaceResolutionRetry = false
        let previous = activePlaceResolution
        activePlaceResolution = outcome
        if outcome.status == .resolved, let id = outcome.selected?.id {
            lastConfidentPlaceID = id
        }
        // Only republish when friend-visible activity would change.
        if shouldRepublishForPlaceOutcomeChange(from: previous, to: outcome) {
            republishPresenceAfterPlaceContextChange()
        }
    }

    func recordPlaceResolutionFailure(expectedDwellSessionID: String) {
        guard !isShutDown else { return }
        guard dwellState.activeSession?.id == expectedDwellSessionID else { return }
        let hadConfidentPlace = activePlaceResolution?.confidentPlaceName != nil
        if activePlaceResolution?.dwellSessionID == expectedDwellSessionID {
            activePlaceResolution = nil
        }
        pendingPlaceResolutionRetry = true
        if hadConfidentPlace {
            republishPresenceAfterPlaceContextChange()
        }
    }

    func clearPlaceResolutionContext(cancelTask: Bool) {
        if cancelTask {
            placeResolutionTask?.cancel()
            placeResolutionTask = nil
        }
        activePlaceResolution = nil
        placeResolveAttemptsForCurrentDwell = 0
        lastPlaceLookupDwellSessionID = nil
        lastPlaceLookupCentroidLatitude = nil
        lastPlaceLookupCentroidLongitude = nil
        pendingPlaceResolutionRetry = false
        // Keep lastConfidentPlaceID across dwells for previous-match boost.
    }

    /// Immediate presence rewrite after place attach / clear (bypasses GPS throttle).
    func republishPresenceAfterPlaceContextChange() {
        guard state.isPresencePublishingEnabled else { return }
        republishLastAcceptedIfPossible()
    }

    /// Compare confident place identity only — ambiguous↔empty need no extra write.
    func shouldRepublishForPlaceOutcomeChange(
        from previous: PlaceResolutionOutcome?,
        to next: PlaceResolutionOutcome
    ) -> Bool {
        previous?.confidentPlaceName != next.confidentPlaceName
            || previous?.selected?.id != next.selected?.id
    }
}
