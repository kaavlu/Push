//
//  LocationSession+Pipeline.swift
//  Push
//
//  Observation consumption, activity inference, draft build, and presence sync.
//

import Foundation

@MainActor
extension LocationSession {
    func consumeObservations() async {
        for await observation in provider.observations {
            guard !Task.isCancelled, !isShutDown else { break }
            guard isConsuming else { continue }
            process(observation)
        }
        if !isShutDown {
            observationTask = nil
        }
    }

    func process(_ observation: LocationObservation) {
        guard !isShutDown, isConsuming else { return }
        guard state.isPresencePublishingEnabled else { return }

        guard let validated = validator.accept(observation, previous: previousAccepted) else {
            return
        }

        previousAccepted = validated.observation
        lastAcceptedValidated = validated
        let evaluationTime = now()
        activityState.recordAccepted(validated.observation, now: evaluationTime)
        // Dwell runs in parallel — never blocks publish and does not mutate drafts.
        dwellState = dwellDetector.process(validated.observation, at: evaluationTime)
        handleDwellPlaceResolution(dwellState, at: evaluationTime)
        state.lastObservation = validated.observation
        state.lastAcceptedAt = evaluationTime
        state.authorization = provider.authorizationState

        if case .publish = PresencePublishPolicy.decisionForHeartbeat(
            now: evaluationTime, snapshot: publishSnapshot
        ) {
            enqueueDraft(from: validated, trigger: .heartbeat)
            return
        }

        let movement = PresencePublishPolicy.decisionForMovement(
            observation: validated.observation,
            now: evaluationTime,
            snapshot: publishSnapshot
        )
        guard case .publish(let trigger) = movement else { return }
        enqueueDraft(from: validated, trigger: trigger)
    }

    func processHeartbeatIfDue() {
        guard !isShutDown else { return }
        guard state.isPresencePublishingEnabled, isConsuming else { return }
        guard case .publish = PresencePublishPolicy.decisionForHeartbeat(
            now: now(), snapshot: publishSnapshot
        ) else { return }
        guard let validated = lastAcceptedValidated else { return }
        enqueueDraft(from: validated, trigger: .heartbeat)
    }

    func republishLastAcceptedIfPossible() {
        guard !isShutDown, state.isPresencePublishingEnabled else { return }
        guard canRunPipeline else { return }
        guard let validated = lastAcceptedValidated else { return }
        enqueueDraft(from: validated, trigger: .republish)
    }

    func enqueueDraft(
        from validated: ValidatedObservation,
        trigger: PresenceSyncTrigger
    ) {
        let evaluationTime = now()
        // Inference never blocks publishing — resolve always returns a result.
        let inferred = activityState.resolve(
            engine: activityEngine,
            trigger: trigger,
            at: evaluationTime
        )
        var draft = inferrer.infer(
            from: [validated],
            manualAvailability: mirroredAvailability(),
            isPublished: state.isPresencePublishingEnabled,
            previous: nil
        )
        ActivityInferencePresentation.apply(
            inferred,
            fallbackActivity: activityState.fallbackActivity(at: evaluationTime),
            to: &draft
        )
        // Availability / Ghost remain orthogonal — never invent from motion.
        draft.isPublished = state.isPresencePublishingEnabled
        if let availability = mirroredAvailability() {
            draft.availability = availability
        }
        enqueueSync(draft, trigger: trigger)
    }

    func mirroredAvailability() -> FriendAvailabilityState? {
        let value = availabilityProvider()
        if value == .ghost { return .maybeDown }
        return value
    }

    func enqueueSync(_ draft: PresenceStatusDraft, trigger: PresenceSyncTrigger) {
        guard !isShutDown else { return }
        guard draft.isPublished else { return }

        pendingTrigger = trigger
        syncTask?.cancel()
        let sync = self.sync
        syncTask = Task { [weak self] in
            do {
                try await sync.upsertCurrentPresence(draft)
                await self?.recordSyncSuccess(draft: draft)
            } catch is CancellationError {
                return
            } catch {
                await self?.recordSyncFailure()
            }
        }
    }

    func recordSyncSuccess(draft: PresenceStatusDraft) {
        guard !isShutDown else { return }
        let at = now()
        state.lastUploadAt = at
        state.lastErrorCode = nil
        publishSnapshot = PresencePublishPolicy.recordingSuccessfulWrite(
            on: publishSnapshot,
            at: at,
            latitude: draft.latitude,
            longitude: draft.longitude
        )
        pendingTrigger = nil
    }

    func recordSyncFailure() {
        guard !isShutDown else { return }
        state.lastErrorCode = LocationSessionErrorCode.upsertFailed
        pendingTrigger = nil
    }

    func performUnpublish(timeout: TimeInterval, recordError: Bool) async {
        syncTask?.cancel()
        syncTask = nil
        pendingTrigger = nil
        publishSnapshot = PresencePublishPolicy.recordingUnpublish(on: publishSnapshot)

        let sync = self.sync
        let work = Task { try await sync.unpublishCurrentPresence() }
        let timeoutTask = Task {
            let nanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            work.cancel()
        }
        defer { timeoutTask.cancel() }

        do {
            try await work.value
            if !isShutDown { state.lastErrorCode = nil }
        } catch {
            if recordError, !isShutDown {
                state.lastErrorCode = LocationSessionErrorCode.unpublishFailed
            }
        }
    }
}
