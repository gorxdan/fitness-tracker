# Pulse

Personal fitness tracker for iOS. Workouts, goals, body metrics, per-workout notes
(feel/pain), music per workout (Spotify / Apple Music), HealthKit integration including
AirPods Pro 3 heart rate.

**Status: MVP feature build complete in code.** All seven `docs/PRODUCT.md` features are
implemented; verified on Linux by unit tests (17/17 in `PulseCore`) and `swiftc -parse`
over every app source. Not yet verified: compilation in Xcode, simulator/device behavior,
HealthKit and MusicKit permission flows, and playback — those need a Mac (`xcodegen
generate`, then build + run the Pulse scheme). Spotify playback is stubbed until the iOS
SDK is added on macOS (see `docs/INTEGRATIONS.md`).

## Build (macOS only)

```
brew install xcodegen   # once
xcodegen generate
open Pulse.xcodeproj    # run the Pulse scheme on a simulator or device
```

## Domain tests (any OS, including Linux)

```
cd PulseCore && swift test
```

`PulseCore/` holds the platform-free domain logic (pure Foundation); everything under `Pulse/`
needs Apple SDKs and builds only via Xcode.

## What exists now

- Full documentation set (`docs/`)
- Xcode project spec (`project.yml`, xcodegen) with HealthKit entitlement + all permission strings
- SwiftData models: Exercise, Workout, SetEntry, Goal, GymLocation
- `PulseCore/` domain logic (BMI, Epley 1RM, volume, weekly buckets, streaks, goal math,
  units, 34-exercise seed catalog) — 17 unit tests, all passing on Linux
- Workout session flow: exercise picker, reps × weight / cardio set logging, one-tap
  repeat-last-set, elapsed timer, finish summary (feel 1–5, pain level + location, notes),
  per-session heart-rate stats, save back to Apple Health
- Home: week stats (workouts, volume, streak), goals snapshot, recent workouts, workout
  detail with per-set breakdown and HR
- Progress: weekly volume by muscle group, per-exercise best e1RM trend, weight trend +
  BMI, resting HR and HRV trends, range switcher (1M/3M/1Y/All), full history
- Goals: weekly workouts / body weight / exercise e1RM, progress bars
- Gyms: save locations (current-location or typed coordinates), geofence radius,
  arrival notification with "start a workout?" deep link into the session
- Music: Apple Music playlist attach + playback via MusicKit; Spotify stub pending SDK
- Settings: Health/Apple Music connections, units (kg/lb), gym management
