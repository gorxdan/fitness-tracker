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

Unit tests: `xcodebuild test -project Pulse.xcodeproj -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17'`

## What exists now

- Full documentation set (`docs/`)
- Xcode project spec (`project.yml`, xcodegen) with HealthKit entitlement + all permission strings
- SwiftData models: Exercise, Workout, SetEntry, Goal
- Domain math (BMI, Epley 1RM, volume) with unit tests
- HealthKit service (auth, body mass/height, per-workout HR stats, save workout)
- Music controller abstraction with Spotify/Apple Music service stubs
- Tab skeleton: Home / Progress / Settings with real empty state and Health permission button
