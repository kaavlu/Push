# Issue #93 — Deterministic Movement and Chilling Inference (I2)

## Status

- [x] Window helpers: path length, accuracy filter
- [x] Protocol `previous` + hysteresis seam
- [x] `DeterministicActivityInferenceEngine` rules
- [x] Unit tests (`DeterministicActivityInferenceTests`) — 17 green
- [x] Verify suite green (I1 suite also green)
- [x] Commit

## Rules (input → output)

Recent `LocationObservation` → unknown | stationary | moving | walking | driving | chilling

Uses: elapsed time, displacement, path length, speed, accuracy, min duration, hysteresis.

## Out of scope

- Arrived / left
- `LocationSession` integration
- Supabase / Realtime / UI / Venues / Core Motion

## Follow-ups

- Issue #94 — Integrate into presence pipeline (I3)

---

# Issue #92 — Activity Inference Domain (I1) — done

See commit history. Domain types, config, fixtures, unknown engine.
