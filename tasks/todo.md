# Live onboarding (auth + post-auth setup)

## Status

- [x] Multi-step email sign-up + photo upload
- [x] Migration `0019` sharing defaults / complete / discover
- [x] Post-auth flow: privacy → location → notifications → friends → done
- [x] `PostAuthOnboardingTests` green
- [ ] Commit / PR

## Live flow

1. Auth gate (signup/signin)  
2. prepareLive (+ photo upload)  
3. If `onboarding_completed_at` null → PostAuthOnboarding  
4. App

## Backend map

| Step | Backend |
|---|---|
| Privacy | `set_global_sharing_defaults` + Ghost + `updatePrivacy` |
| Location | `LocationSession.startIfEligible` (when-in-use) |
| Notifications | System permission only (no APNs yet) |
| Friends | `discover_profiles` + `send_friend_request` |
| Done | `complete_onboarding` |

## Non-goals

- Phone auth
- Contact-book import
- Remote push delivery
