# Issue #101 — Resolve Confirmed Dwells to Places (I3)

## Goal

Resolve a confirmed dwell centroid to nearby real-world POIs and attach a structured result to the active dwell. Do **not** yet convert results into friend-facing activity copy (`At Starbucks` is a later issue).

Builds on #99 (cluster) and #100 (arrival/departure).

## Abstraction

```
PlaceResolving
  resolve(PlaceResolutionRequest) async throws → PlaceResolutionOutcome
```

- Domain protocol is free of MapKit / Core Location types (Doubles only).
- Production: `MapKitPlaceResolver` (POI search + reverse-geocode fallback).
- Mock / tests: `NoOpPlaceResolver`, `FixedPlaceResolver`.
- Ranking is pure (`PlaceCandidateRanker`) so selection rules are unit-tested without MapKit.

## Models

| Type | Role |
|---|---|
| `ResolvedPlaceCandidate` | id, name, coordinate, category, distance, score |
| `GeographicPlaceContext` | reverse-geocode fallback (address / locality) |
| `PlaceResolutionOutcome` | status + optional selected + ranked candidates + fallback |
| `PlaceResolutionRequest` | dwell session id, centroid, accuracy, dwell radius, previous id |

### Status

| Status | Meaning |
|---|---|
| `resolved` | One confident named POI selected |
| `ambiguous` | Multiple plausible POIs — **no** selection |
| `geographicOnly` | No confident POI; reverse-geocode context only |
| `empty` | Nothing useful nearby |

Never auto-pick nearest when top scores are close (`ambiguityScoreDelta`).

## When to resolve

| Trigger | Action |
|---|---|
| Dwell `.arrived` | Resolve for that session |
| Centroid moves ≥ `centroidChangeReresolveMeters` while dwelling | Re-resolve |
| Prior failure while still dwelling | Retry up to `maxResolveAttempts` |
| Every GPS fix | **Do not** lookup |
| `.departed` / shutdown | Cancel in-flight; clear active outcome |

## Ranking signals

- Distance from dwell centroid (primary)
- Representative accuracy + dwell radius (inside likely area boosts; far outside penalized)
- Optional category weight (light)
- Previous confirmed place id boost when available
- Ambiguity gate: require score ≥ `minScoreForSelection` **and** margin over runner-up ≥ `ambiguityScoreDelta`

Poor accuracy lowers effective selection (stricter) rather than inventing a place.

## Integration

- `LocationSession` owns `placeResolver`, `activePlaceResolution`, lookup bookkeeping.
- Outcome is **internal** — not written to presence drafts, activity labels, Ghost, or UI in this issue.
- Failures log-safe and leave the existing presence pipeline unchanged.
- Factory: live/Core Location path → `MapKitPlaceResolver`; mock → `NoOpPlaceResolver`.

## Non-goals

- “At {place}” activity strings
- Eating / workout / date inference
- Availability, place correction UI, home/work learning, co-presence, ML, map redesign

## Acceptance

- Arrival triggers one lookup (deduped for same dwell/centroid)
- Clear match → `resolved` + selected candidate
- Ambiguous neighbors → `ambiguous`, no selected
- No POIs → geographic fallback or empty
- Departure clears active place context
- Architecture swappable via `PlaceResolving`

## Tests

`PlaceResolutionTests`: ranker + session orchestration with `FixedPlaceResolver`.
