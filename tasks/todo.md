# Issue #139 — Redesign Push Live Small-Group Puck Detail Sheet

## Status

- [x] Clarify scope / primary action / avatars / surface with product
- [x] Multi-person title helpers (`A & B`, `A, B & C`, `A, B + N`)
- [x] Compact Friends-row sheet content (`FriendDetailGroupContent`)
- [x] Cream map-popup surface for multi-person sheets
- [x] Adaptive primary: Ask to join when joinable; else Start push
- [x] Wire `FriendDetailSheet` / bottom-sheet height + chrome
- [x] Unit tests for titles, activity/location lines, join visibility

## Decisions

- Scope: all multi-person map sheets (hangout, cluster, friendGroup)
- Join unavailable → hide Ask to join; Start push becomes primary; Directions secondary only
- Avatar stack: max 3 faces + `+N` overflow; fixed stack width
- Surface: solid cream (`MapPopupSheetSurface.solidCream`) over map for multi-person

## Out of scope

- Individual friend sheet redesign
- Live “ask to join” backend (still toast)
- Regional cluster detail card
