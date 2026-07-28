# Issue #100 — Arrival / Departure Lifecycle (I2)

## Goal

Track the lifecycle of a **confirmed** dwell so Push knows when the user arrived somewhere and when they meaningfully left. Preserve completed-session metadata for later venue resolution.

Builds on Issue #99 (I1) place-cluster detection. Still no venue lookup, activity labels, presence UI, or DB changes.

## Lifecycle model

### Phases (durable cluster state — unchanged from I1)

```
moving → candidateDwell → dwelling → moving
```

### Transitions (edge-triggered, once per dwell)

```
arrived   — candidate promotes to confirmed dwelling (exactly once)
departed  — confirmed dwell ends after hysteresis (exactly once)
```

While the same dwell stays active, **no repeated arrivals**. Between departure and the next confirmation, no further transitions.

### Sessions

| Field | Meaning |
|---|---|
| `startedAt` | First accepted inlier of the cluster |
| `arrivedAt` | Wall time when the dwell was confirmed (arrival event) |
| `departedAt` | Wall time when departure hysteresis completed (`nil` while active) |
| `lastConfirmedAt` | Last inlier / near-zone sample still attributed to the place |
| centroid, sampleCount, representativeAccuracy | From I1 cluster snapshot |

- **Active session** while `phase == .dwelling`
- **Last completed session** retained after `.departed` for downstream place resolution (replaced on next completed departure; cleared on `reset()`)

## Departure hysteresis

Ending a confirmed dwell requires **sustained** evidence, not a single bad fix.

1. **Inlier zone** (`≤ dwellRadiusMeters`, default 40 m) — still dwelling; clear any departure tracker; update cluster metrics.
2. **Near zone** (`≤ departureRadiusMeters`, default 100 m) — still at a large venue / parking lot; **do not** count as departure; clear departure tracker; may refresh `lastConfirmedAt`.
3. **Outside departure radius** or **clearly moving** — accumulate departure evidence.
4. Confirm departure only when **both**:
   - consecutive outside samples ≥ `minimumDepartureSampleCount`
   - wall-clock span of the departure streak ≥ `minimumDepartureDuration`
5. One inaccurate fix is still ignored (I1 quality gate) and never ends a dwell.
6. Returning inside the near zone **before** thresholds are met cancels the departure streak.

Candidate-phase exit stays stricter (I1 outlier budget) so unconfirmed stops still fail fast.

## Parking / no activity toggle

Dwell remains parallel to activity inference. Driving samples do not seed clusters; after parking and remaining low-speed nearby, a single dwell confirms. Activity may still read Driving → Stationary independently — dwell does not rewrite labels or presence drafts (I1 contract).

## Configuration additions (`DwellDetectionConfiguration`)

| Constant | Default | Role |
|---|---|---|
| `departureRadiusMeters` | 100 | Large-venue / near-lot soft zone |
| `minimumDepartureDuration` | 90 s | Sustained leave time |
| `minimumDepartureSampleCount` | 3 | Sustained leave samples |

I1 gates unchanged.

## Pipeline

- `DeterministicDwellDetector.process` returns `DwellDetectionState` with optional `transition`, `activeSession`, `lastCompletedSession`.
- `LocationSession` already stores `dwellState`; expose completed session via test hook.
- Still no draft / publish / Ghost / UI side effects.

## Non-goals

- Venue lookup / reverse geocode
- Named activity labels
- Presence UI
- Availability inference
- Co-presence

## Acceptance

| Criterion | Verification |
|---|---|
| One arrival per confirmed dwell | Transition `.arrived` once on promote |
| No repeated arrivals while active | Stay `.dwelling` with `transition == nil` |
| Brief near-zone movement / GPS drift | Stay dwelling |
| One bad fix | Ignored; no departure |
| Sustained leave | One `.departed` + completed session |
| Re-arrival | New session + second `.arrived` |
| Parking then stay | One dwell (fixture) |

## Tests

`DwellLifecycleTests` (and fixture extensions): arrival, large-venue remain, GPS drift, departure, re-arrival, single inaccurate fix, parking-then-stay.
