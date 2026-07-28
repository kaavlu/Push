# Issue #99 — Deterministic Dwell Detection (I1)

## Goal

Add an independently testable, deterministic dwell detector that consumes validated location fixes and tracks whether the user has stopped long enough for a meaningful dwell. Wire it into `LocationSession` **without** changing activity labels, Ghost behavior, publishing cadence, availability, DB schema, or UI.

## Why separate from activity inference

`DeterministicActivityInferenceEngine` already classifies window-level motion (including `.stationary` / `.chilling`). Dwell detection answers a different question: **is there a stable place cluster with a start time and centroid?** That cluster is the foundation for later arrive/leave and venue work; it must not fold into activity labels yet.

## Domain model

### Phase

```
moving → candidateDwell → dwelling
                ↓              ↓
             moving         moving
```

| Phase | Meaning |
|---|---|
| `moving` | Not building a dwell (transit, insufficient evidence, or exited). |
| `candidateDwell` | Low-motion cluster forming; not yet confirmed. |
| `dwelling` | Confirmed dwell with a stable centroid and duration. |

### Confirmed / candidate snapshot fields

When phase is `candidateDwell` or `dwelling`, expose:

- Stable centroid (lat / lon)
- Start time (first accepted inlier of this cluster)
- Last confirmed time (last accepted inlier)
- Duration (`lastConfirmed − start`)
- Sample count (accepted inliers only)
- Representative accuracy (mean horizontal accuracy of inliers)

## Algorithm (deterministic, incremental)

Process one `LocationObservation` at a time (session-friendly). No Core Location types.

1. **Quality gate** — drop samples with non-finite coords, non-positive accuracy, accuracy worse than `maxHorizontalAccuracyMeters`, or reported speed above `maxSpeedMetersPerSecond`. Dropped samples do not advance or reset state.
2. **`moving`** — first quality sample starts a `candidateDwell` seed (centroid = sample, count = 1).
3. **`candidateDwell`**
   - Inlier if great-circle distance to current centroid ≤ `dwellRadiusMeters` and speed OK.
   - Inlier → append, bump count / lastConfirmed, recompute centroid from unlocked inliers only (first `centroidLockSampleCount` samples; then freeze).
   - Outlier → `consecutiveOutliers++`; if > `maxConsecutiveOutliers`, reset to `moving`.
   - Promote to `dwelling` when `sampleCount ≥ minimumSampleCount` **and** duration ≥ `minimumDwellDuration`. Freeze centroid at promotion.
4. **`dwelling`**
   - Inlier → update lastConfirmed, count, representative accuracy; **do not** wander the centroid.
   - Outlier streak beyond `maxConsecutiveOutliers` → `moving` (dwell ends). Brief GPS blips do not end the dwell.
5. **Single fix / brief stop / walk-by** never promote: min samples ≥ 3 and min duration (default 3 minutes) block traffic lights and pass-throughs.

## Configuration (`DwellDetectionConfiguration`)

| Constant | Default | Rationale |
|---|---|---|
| `dwellRadiusMeters` | 40 | Room-scale cluster; wider than typical pedestrian GPS jitter |
| `minimumDwellDuration` | 180 s | Longer than typical red light; shorter than “hanging out” |
| `minimumSampleCount` | 3 | Single/double fix cannot confirm |
| `maxHorizontalAccuracyMeters` | 50 | Stricter than pipeline accept (100 m) |
| `maxSpeedMetersPerSecond` | 0.5 | Reject clearly moving samples |
| `maxConsecutiveOutliers` | 2 | Tolerate GPS blips without reset |
| `centroidLockSampleCount` | 5 | Stabilize centroid early; freeze on confirm |

All thresholds live in one enum — no magic numbers in the detector.

## Pipeline integration

- `LocationSession` owns a `DeterministicDwellDetector` (injectable for tests).
- After a validator accept in `process(_:)`, call `dwellDetector.process(...)` and store the latest `DwellDetectionState`.
- **Do not** feed dwell into `ActivityInferencePresentation`, drafts, sync, Ghost, or availability.
- Reset detector on `shutdown()`.
- Test hooks only: expose latest phase / confirmed snapshot for unit tests.

## Non-goals (this issue)

- Venue lookup / reverse geocode
- Arrival / departure events or friend-facing copy
- Mapping dwell → `.chilling` or any activity label
- Database / Realtime / presence draft fields
- UI

## Acceptance

| Criterion | Verification |
|---|---|
| Sustained stationary cluster → one stable `dwelling` | Fixture sequence ≥ min duration + samples |
| Single fix / short stop / walk-by → never `dwelling` | Unit cases |
| GPS drift inside radius does not reset start or wander centroid after lock | Centroid frozen; start time stable |
| Traffic-light-length stop stays `candidateDwell` or `moving` | Duration < minimum |
| Activity labels + publish path unchanged | Session integration test: drafts still from activity engine only |

## Tests

- `DwellDetectionTests` — pure domain (state machine + fixtures).
- Light `LocationSession` coverage that accepted fixes update dwell state without changing inferred activity application.

## Files

| Path | Role |
|---|---|
| `Push/Data/Domain/DwellDetection.swift` | Phase, snapshot, result, protocol, no-op |
| `Push/Data/Domain/DwellDetectionConfiguration.swift` | Thresholds |
| `Push/Data/Domain/DeterministicDwellDetector.swift` | State machine |
| `Push/Data/Domain/DwellDetectionFixtures.swift` | Deterministic sequences |
| `PushTests/DwellDetectionTests.swift` | Unit tests |
| `LocationSession` / `+Pipeline` | Silent wiring + reset |
