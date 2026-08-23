# Architecture

## Stack (decisions, with reasons)

| Choice | Decision | Why |
|---|---|---|
| UI | SwiftUI | iOS 26-only target; no UIKit needed except media pickers wrapped in `UIViewControllerRepresentable` |
| Persistence | SwiftData | Native, no schema files, iCloud backup path exists later |
| Health | HealthKit | Only way to read AirPods Pro 3 HR and Apple Fitness data |
| Charts | Swift Charts | Native, consistent with system look |
| Music | MusicKit (Apple) + Spotify iOS SDK | Both attach-playlist + start-playback flows |
| Min target | iOS 26.0 | Owner's device; current release is iOS 26.6.1 |
| Backend | None | Single user, on-device |

## Layers

```
PulseCore/          platform-free SwiftPM package (pure Foundation): domain math, goal
                    math, units, seed catalog + tests
Pulse/
  App/          app entry, root tab view, AppDelegate (notification taps), AppServices,
                AppState (session sheet + arrival deep link)
  Features/     Home (+ workout detail), Session (logging, pickers, summary),
                Progress (charts + history), Goals (+ editor), Gyms (+ editor), Settings
  Domain/
    Models/     SwiftData @Model classes (see docs/DATA_MODEL.md)
  Services/     HealthKitService, LocationService (geofence + notifications),
                SpotifyService (stub), AppleMusicService (MusicKit), MusicController
```

Rules:

- **Views → view models → services.** Views never `import HealthKit`, `MusicKit`, or the Spotify
  SDK. All platform access sits behind protocols in `Services/` so previews and tests run with
  fakes.
- **Domain is dependency-free.** Pure logic lives in `PulseCore/` (Linux-verifiable);
  `Pulse/Domain/Models/` holds only SwiftData `@Model` classes.
- **One SwiftData container** in `PulseApp`, injected via `.modelContainer` and `@Environment`.
- **Music is one abstraction.** `MusicController` exposes `play(workout:)`, `pause()`,
  `currentTrack` and is backed by `SpotifyService` or `AppleMusicService` depending on the
  playlist's provider. Views don't know which.

## HealthKit data flow

Read side: `HealthKitService.requestAuthorization()` fires once at first launch, then
from Settings on demand (status row plus a link to the app's Health settings page);
per-workout HR is a query over the session's time range — there is no live streaming in MVP.
Write side: finishing a workout saves an `HKWorkout` + active energy so Apple Fitness rings
reflect sessions logged in Pulse. BMI is computed on demand from height + latest body mass;
it is never stored.

## Spotify vs Apple Music

| | Apple Music | Spotify |
|---|---|---|
| Auth | MusicKit system permission | Spotify SDK OAuth (needs redirect URL scheme + token exchange) |
| Pick playlist | MusicKit catalog/user library query | Web API via SDK (`playlist-read-private`) |
| Play | `ApplicationMusicPlayer` | Remote control of installed Spotify app |

Both are best-effort: if the provider app is missing or auth lapses, the workout proceeds
without music and the UI says why in one line.

## Verification workflow (phase 2 gate)

On this Linux box — now real, not just structural:
1. `cd PulseCore && swift test` — domain logic compiles and tests pass (Swift 6.3 toolchain at
   `~/swift`; package is pure Foundation, no Apple frameworks).

On a Mac:
2. `xcodegen generate` — project generates clean.
3. `xcodebuild … build` for the app target — zero warnings policy for new code.
4. Simulator manual pass: launch, tab through Home/Progress/Settings, exercise HealthKit
   permission prompt (Simulator has sample Health data), verify empty states.
5. Device pass before calling any integration "done": AirPods Pro 3 HR visible on a finished
   workout, playlist playback from both providers, workout saved back to Apple Fitness,
   gym-arrival notification firing.

Rule: new pure logic goes in `PulseCore/` (Linux-verifiable); only code that genuinely needs
an Apple framework goes in `Pulse/`.
