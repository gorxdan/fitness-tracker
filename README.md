# Pulse

Personal fitness tracker for iOS. Workouts, goals, body metrics, per-workout notes
(feel/pain), music per workout (Spotify / Apple Music), HealthKit integration including
AirPods Pro 3 heart rate.

**Status: ground layer complete (docs + skeleton). Audit next, then feature build.**
See `AGENTS.md` for conventions and the doc map in `docs/`.

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
- Domain math (BMI, Epley 1RM, volume) in `PulseCore/` with unit tests — runs on Linux
- HealthKit service (auth, body mass/height, per-workout HR stats, save workout)
- Music controller abstraction with Spotify/Apple Music service stubs
- Gym location model + arrival-detection service skeleton
- Tab skeleton: Home / Progress / Settings with real empty state and Health permission button
