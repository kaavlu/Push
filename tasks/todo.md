# Issue #92 — Activity Inference Domain and Engine Interface (I1)

## Status

- [x] Domain types (`InferredActivityKind`, `InferredActivityResult`)
- [x] `ActivityInferenceEngine` protocol + `UnknownActivityInferenceEngine`
- [x] Centralized `ActivityInferenceConfiguration`
- [x] Observation-window helpers + deterministic fixtures
- [x] Unit tests (`ActivityInferenceTests`) — 17 green
- [x] Verify suite green
- [x] Commit

## Scope (from issue)

Create only domain types, protocol, configuration, and deterministic test fixtures.
No real inference logic beyond returning `unknown`.

### Out of scope

- Arrived / left
- Stateful transitions
- `LocationSession` integration
- Presence drafts / Supabase / UI / venue / co-presence

## Follow-ups

- Issue #93 — Deterministic movement and chilling rules (I2)
- Issue #94 — Integrate into presence pipeline (I3)
