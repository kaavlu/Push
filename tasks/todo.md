# Issue #94 — Integrate Activity Inference into Presence (I3)

## Status

- [x] Map inferred kinds → `PresenceActivity` / draft fields (existing activity_name/symbol)
- [x] `LocationSessionActivityState` observation window + last-valid hold
- [x] `LocationSession` orchestration (engine → draft → sync)
- [x] Factory wires `DeterministicActivityInferenceEngine`
- [x] Heartbeats preserve latest valid activity
- [x] Ghost / availability unchanged; unknown still publishes
- [x] Remote activity patches via existing LiveDataStore path
- [x] `ActivityInferenceIntegrationTests` — 9 green
- [x] Regression `LocationSessionTests` — 18 green
- [x] Commit

## Flow

```
validated observation
→ activity engine
→ latest inferred activity
→ presence draft (activity_name/symbol)
→ existing Supabase write path
→ existing Realtime path
```

## Out of scope

- Arrived / left
- Friend-facing UI
- New DB columns (reuse activity_name / activity_symbol)

## Prior

- #92 I1 domain — done
- #93 I2 deterministic rules — done
