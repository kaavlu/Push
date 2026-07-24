# Confirmation Dialogs — Design Spec (Issue #83)

**Status:** Approved for implementation  
**Date:** 2026-07-24  
**Issue:** [#83 — Audit and Standardize Confirmation Popups](https://github.com/kaavlu/Push/issues/83)  
**DS decision:** DS-090 (supersedes DS-009 for destructive confirms; narrows DS-066)

---

## Problem

Push still uses system `confirmationDialog` / `.alert` for destructive and high-stakes actions (sign out, delete account, remove friend, block, leave/delete group, cancel/delete push). That reads as unfinished generic iOS chrome on a product that otherwise uses cream/glass design-system surfaces.

Issue #63 intentionally deferred branded destructive alerts (DS-009 / catalog “Explicitly deferred”). Issue #83 reopens that surface as a first-class design-system family.

---

## Goals

1. Shared Push-styled **centered confirmation card** for destructive (and future standard) confirms.
2. One presentation/dismissal pattern app-wide; no one-off popup chrome per feature.
3. Preserve existing copy, validation, mutation, cancel, and error-handling behavior.
4. Destructive actions stay deliberate: explicit confirm required; cannot fire from overflow alone.
5. Accessibility: Dynamic Type, VoiceOver, reduced motion, smaller screens.

## Non-goals

- Multi-action menus (profile/group photo choose/remove) — stay system `confirmationDialog` this pass.
- Info-only alerts (photo failure, connector “Got it”) — stay system `.alert` / `ActionErrorBanner`.
- Branding system `Menu` / `contextMenu` / `PhotosPicker` / OS permission sheets.
- Redesign of `ActionErrorBanner` or toast chrome.
- Onboarding/auth-specific dialogs.

---

## Decisions (product)

| Topic | Decision |
|---|---|
| Presentation | Centered modal card over a dim scrim |
| Surface | Solid cream card (`pushSolidCreamCard`) |
| Scope this pass | **Destructive confirms only** |
| Multi-action / info | System UI retained |
| Presentation ownership | Local `isPresented` / pending-item state per call site (no global presenter) |
| Scrim tap / outside dismiss | Cancels (no confirm side effect) |
| Confirm visual | Filled capsule using `PushControlColors.destructive` (danger role, **not** a third primary CTA) |
| Cancel visual | Secondary text control under confirm |
| Loading | Optional confirm loading/disabled; default path dismisses then runs action (matches system) |

---

## API

### Models

```swift
enum PushConfirmationRole {
    case destructive
    case primary // reserved; few/no call sites this pass
}

struct PushConfirmationConfig: Equatable {
    var title: String
    var message: String?
    var confirmTitle: String
    var confirmRole: PushConfirmationRole // default .destructive
    var cancelTitle: String // default "Cancel"
}
```

### View + modifier

- **`PushConfirmationDialog`** — pure content: title, optional message, confirm + cancel buttons, loading/disabled on confirm.
- **`.pushConfirmation(isPresented:…)`** — overlay presenter (scrim + card + motion).
- **`.pushConfirmation(item:…)`** — same for `Binding<Item?>` pending payloads (remove member, unblock, transfer).

Call sites keep existing titles/messages; only the presentation chrome changes.

### Tokens

| Token | Use |
|---|---|
| `PushCreamTokens` / `pushSolidCreamCard` | Card surface |
| `PushOpacityTokens.dialogScrim` | Dim behind dialog (stronger than menu `scrim`) |
| `PushMotion.menuPresent` / `contentCrossfade` | Present/dismiss; reduced motion → opacity only |
| `PushControlColors.destructive` | Confirm fill (destructive role) |
| `PushControlColors.textEspresso` / `textSecondary` | Title / message / cancel |
| `PushRadiusTokens.card(layout)` | Card corners |
| Named layout constants in the dialog file | Padding, max width, button height — no freeform magic in features |

---

## Visual layout

```
┌──────────────────────────────────┐
│           dim scrim              │
│     ┌────────────────────┐       │
│     │  Title?            │       │
│     │  Optional message  │       │
│     │                    │       │
│     │  [ Confirm action ]│       │  ← filled destructive (or primary)
│     │     Cancel         │       │  ← text secondary
│     └────────────────────┘       │
└──────────────────────────────────┘
```

- Max card width capped; horizontal inset for compact phones.
- Title: semibold headline, espresso.
- Message: callout/subheadline secondary; multi-line, Dynamic Type.
- Buttons full width inside card; confirm above cancel.
- Accessibility: dialog traits, labelled title/message, confirm/cancel buttons; reduce-motion safe transitions.

---

## Migration inventory (destructive only)

| Flow | Call site | Notes |
|---|---|---|
| Sign out | `ProfileView` | Keep `isSigningOut` guard |
| Delete account | `ProfileView` | Message from `ProfileCopy` |
| Remove friend | `PushExpandablePersonRow` | Personalized title |
| Block | `PushExpandablePersonRow` | Personalized title |
| Unblock | `BlockedUsersView` | Item binding |
| Leave group | `GroupManageView` | `GroupDetailCopy` |
| Delete group | `GroupManageView` | `GroupDetailCopy` |
| Transfer ownership | `GroupManageView` | Item binding after transfer sheet |
| Remove member | `GroupDetailView` | Item binding |
| Cancel invite | `GroupDetailView` | Item binding |
| Delete push | `StartPushFlowView` | Edit trash |
| Cancel push | `PushPlansPlanCard` | After context menu |

**Unchanged system UI:** photo menus (Profile, Group detail), photo error alert, connector alert, `Menu` overflow, plan `contextMenu` (only the follow-up confirm migrates).

---

## Behavior rules

1. Opening overflow/`Menu`/row action only **presents** the dialog — mutation runs on confirm.
2. Cancel, scrim tap, and programmatic dismiss clear presentation state and run no mutation.
3. Confirm dismisses presentation then invokes `onConfirm` (unless caller keeps presentation for loading).
4. Failed mutations continue to use `ActionErrorBanner` (not the confirmation card).
5. Copy stays concise and action-specific (existing strings preferred).

---

## Design-system law updates

1. **DS-090** — Branded destructive confirmation family; migration required for inventory above.
2. **DS-009** — Superseded for destructive confirms; historical note retained.
3. **DS-066** — System `Menu` / `contextMenu` retained; destructive *confirmation* uses DS-090; photo multi-action menus still system `confirmationDialog`.
4. **Catalog** — Add dialogs component; remove “Custom branded destructive alerts” from deferred; hard-ban table: custom freeform popovers still banned — use DS-090 or system Menu/contextMenu/photo dialogs.

---

## Files

| Path | Role |
|---|---|
| `Push/DesignSystem/Components/Dialogs/PushConfirmationDialog.swift` | Config, dialog view, modifiers |
| `Push/DesignSystem/Tokens/PushOpacityTokens.swift` | Add `dialogScrim` |
| Migrated feature/DS views | Replace destructive `confirmationDialog` |
| `docs/design-system.md` | Catalog entry |
| `tasks/design-system-decision-log.md` | DS-090 |
| `PushTests/PushConfirmationTests.swift` | Config/role + copy smoke tests |
| DEBUG previews | Destructive + message + loading |

Register new Swift files via `scripts/pbxproj_add.py`.

---

## Testing / verification

- Unit: `PushConfirmationConfig` defaults/roles; optional copy constants non-empty where shared.
- Build: `scripts/test.sh build`
- Scoped: `scripts/test.sh suite PushConfirmationTests` (and existing suites touched by call sites if needed)
- Manual smoke: Profile sign-out/delete; Friends remove/block; Blocked unblock; Group leave/delete/transfer/remove; Plans cancel; Start Push delete.

---

## Acceptance (maps to issue)

- [x] Audit documented  
- [x] Shared DS confirmation component shipped  
- [x] Destructive inventory migrated  
- [x] Photo menus / info alerts intentionally system and documented  
- [x] Behavior (cancel, confirm, errors) preserved  
- [x] Previews + tests  
- [x] Catalog + DS-090 updated  
