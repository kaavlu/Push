# Screenshots

Fresh captures for the root [README](../../README.md), taken from the DEBUG mock build on the worktree iPhone 17 Simulator.

| File | Screen | How captured |
|---|---|---|
| `01-map.png` | Live map | Default launch |
| `02-friends.png` | Friends | `--friends` |
| `03-onboarding.png` | Onboarding welcome | `--onboardinglab` |
| `04-pushes.png` | Pushes | `--plans` |
| `05-profile.png` | Profile | `--profile` |
| `06-alerts.png` | Alerts | `--alerts` |

Re-capture:

```bash
./scripts/run-ios-sim.sh -- --friends
# …then simctl screenshot, or use the other DEBUG launch args above
xcrun simctl io booted screenshot docs/screenshots/02-friends.png
```

Resize for GitHub after capture (keep longest side ≤ ~1200px) so the README stays skimmable.
