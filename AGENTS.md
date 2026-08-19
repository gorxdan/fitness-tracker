# AGENTS.md — Conventions for AI agents working in this repo

App: **Pulse** — a personal-use iOS fitness tracker (workouts, goals, body metrics, workout
notes, music per workout). Local-first, no backend, single user (the owner's iPhone).

## Ground rules

1. **macOS-only builds.** Swift/Xcode toolchains do not exist on Linux. Do not claim a build,
   test run, or simulator verification happened unless terminal output shows it. On this
   machine, verify what is verifiable: file structure, naming consistency, doc↔code agreement.
2. **Docs are the contract.** `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`,
   `docs/INTEGRATIONS.md` define what to build. If code and docs disagree, either fix the code
   or update the doc in the same change — never let them drift silently.
3. **Scope discipline.** Personal app: no accounts, no cloud sync, no analytics, no onboarding
   screens beyond permission prompts. When in doubt, cut the feature, don't abstract it.
4. **No word salad.** Docs and code comments state facts in plain sentences. No marketing tone,
   no filler paragraphs, no "This class represents a class that…".

## Toolchain (verified 2026-08-19)

| Tool | Version | Notes |
|---|---|---|
| Xcode | 27 | Current release; Xcode 26.3+ has agentic coding features |
| iOS SDK target | 26.0 | Deployment target. iOS 26.6.1 is the shipping release; iOS 27 is beta — do not target it |
| Swift | 6.x | Strict concurrency enabled |
| Project generation | xcodegen | `project.yml` is the source of truth. `Pulse.xcodeproj` is generated, never hand-edited |
| Dependencies | None yet | Spotify iOS SDK added later via SPM (see `docs/INTEGRATIONS.md`); keep it the only one |

Build commands (run on macOS, from repo root):

```
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Code conventions

- **SwiftUI + SwiftData.** Views in `Pulse/Features/<Feature>/`, SwiftData `@Model` classes in
  `Pulse/Domain/Models/`, pure logic in `Pulse/Domain/`. Services (HealthKit, Spotify, Apple
  Music) behind protocols in `Pulse/Services/` — views never import HealthKit/MusicKit/Spotify
  directly.
- **Concurrency:** UI is `@MainActor`. Services are `actor` or `final class` with async methods.
  No Combine, no callbacks where `async/await` works.
- **Charts:** Swift Charts only. No chart libraries.
- **Formatting:** 4-space indent, 100-col soft limit, `swift-format` default style otherwise.
- **Naming:** types `UpperCamelCase`, meaning-first (`WorkoutSession`, not `SessionManager`).
- **Tests:** Swift Testing (`import Testing`). Pure domain logic (BMI, volume, streaks) gets unit
  tests in `PulseTests/`. Feature tests come with the feature, not before it exists.

## Workflow phases (agreed with owner)

1. **Ground layer** — docs + skeleton (this state).
2. **Audit / validate / verify** — check docs↔code↔permissions consistency, then build+test on macOS.
3. **Build** — feature-by-feature in MVP order defined in `docs/PRODUCT.md`.

Definition of done for any feature: builds, tests pass, HealthKit/Music permission flows
exercised in Simulator or on device, and every changed screen manually verified.

## File map

```
AGENTS.md            this file
README.md            quick start + status
docs/PRODUCT.md      features, MVP order, user flows, design language
docs/ARCHITECTURE.md stack, layering, module map, verification workflow
docs/DATA_MODEL.md   entities, fields, relationships, HealthKit mapping
docs/INTEGRATIONS.md HealthKit / Spotify / Apple Music setup and permissions
project.yml          xcodegen spec (source of truth for the Xcode project)
Pulse/               app sources
PulseTests/          unit tests
```
