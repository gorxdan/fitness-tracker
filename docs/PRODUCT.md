# Product spec — Pulse

Personal fitness tracker for one user (the owner). Everything lives on-device; HealthKit is the
only inbound data source, Spotify/Apple Music the only outbound integrations.

## What it does (MVP, in build order)

1. **Log a workout.** Pick exercises, log sets as reps × weight, add a title and date. Session
   screen shows elapsed time and one-tap "repeat last set".
2. **Workout notes.** Per-workout: mood/how you feel (1–5 scale), pain level (none/mild/
   moderate/severe), pain location (free text), free-form notes.
3. **HealthKit read.** Heart rate (incl. AirPods Pro 3 during-workout HR), resting HR, HR
   variability, body mass, height, energy, Apple Fitness workouts. Per-workout HR pulled by
   time range against the session.
4. **Progress.** Swift Charts screens: strength volume per muscle group over time, per-exercise
   best set / estimated 1RM trend, weight trend + BMI, workout history list with per-workout
   HR stats.
5. **Goals.** Simple targets: weekly workouts, weight (kg/lb), estimated 1RM for an exercise.
   Status shown on Home.
6. **Gym locations.** Save named gym locations (map pin or current location). Arriving at a
   saved gym triggers a local notification: "At Ironworks — start a workout?" tapping it opens
   the session screen with workout templates ready to pick.
7. **Music per workout.** Attach one Spotify or Apple Music playlist to a workout; one tap to
   start playback when the session starts. Playback control stays in the session screen.

## Later (not in MVP)

Rest timers, plate calculator, iCloud backup, custom exercises beyond the seed library,
CSV export, watchOS companion.

## Core user flows

- **Start a workout:** Home → "Start Workout" → (optional: pick playlist, starts playing) →
  add exercise → log sets → finish → summary with notes (feel/pain) + HR stats.
- **Check progress:** Progress tab → pick a chart (volume, exercise trend, weight/BMI) →
  range switcher (1M / 3M / 1Y / All).
- **Set a goal:** Home → Goals → add target → status updates automatically.

Three tabs only: **Home**, **Progress**, **Settings**. Anything more is scope creep.

## Design language

- Follows the platform: system background/elevated colors, SF Pro via `.font(_:)` text styles,
  SF Symbols for all iconography, full dark mode, `chartStyle` defaults from Swift Charts.
- Accent color: system teal, used sparingly — active sets, goals in reach, live HR.
- No gradients-as-decoration, no glassmorphism stacking, no custom fonts, no splash screens.
- Big tap targets for logging (used mid-set, one-handed); secondary data small and quiet.
- Every list has a real empty state with one action button ("Log your first workout").

## Non-goals

Multi-user, social, cloud sync, subscriptions, App Store distribution (personal build only,
free provisioning), food logging.
