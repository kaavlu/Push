# Issue #81 — Live App Cleanup

**Issue:** https://github.com/kaavlu/Push/issues/81  
**Base:** main (includes #79 Core Location)

## Status

- [x] Plan from issue
- [x] Map empty CTA only when `friendsCount == 0` (not when friends hide presence)
- [x] Open map on user GPS/self presence instead of SF default
- [x] Session-cache friendships + blocked users; warm with social graph (lag fix)
- [x] Remove shadow from Start Push location typing bar
- [x] Tests (EmptySurfaceTests, LiveDataStoreTests, FriendRelationshipTests)
- [ ] PR

## Fixes

| # | Bug | Fix |
|---|---|---|
| 1 | Add-friends map popup when friends exist but no presence | `MapViewModel.surfacePhase` uses friend count |
| 2 | Map opens in SF | Initial focus from GPS (prefer) or self presence |
| 3 | Visible lag on friends/pushes | Cache `friendships` + blocked in `LiveDataStore.warm` |
| 4 | Location field shadow | `pushGlassBackground(showsShadow: false)` on Where field |

## Non-goals

- Realtime subscriptions
- Custom location permission onboarding UI
- Feed backend
