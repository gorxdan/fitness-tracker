# AGENTS.md

Conventions for **Pulse** — a personal-use iOS fitness tracker (workouts, goals, body
metrics, per-workout notes, music per workout). Local-first, no backend, single user
(the owner's iPhone). Development happens on a Linux box without Xcode; read `## Rules`
and `## Workflow phases` before structuring any change.

## Layout

`docs/` (the contract: product, architecture, data model, integrations) | `Pulse/App`
(entry point, root tab view) | `Pulse/Features/<Feature>/` (SwiftUI views) |
`Pulse/Domain/` (SwiftData `@Model` classes + pure logic) | `Pulse/Services/` (HealthKit,
Spotify, Apple Music, location — behind protocols) | `PulseCore/` (platform-free SwiftPM
package: domain math + tests; the only Linux-buildable tree) | `project.yml` (xcodegen
spec — source of truth for `Pulse.xcodeproj`)

## Rules

Docs are the contract (`docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`,
`docs/INTEGRATIONS.md`) — when code and docs disagree, fix the code or the doc in the
same change; never let them drift | never claim a build, test run, or simulator
verification unless terminal output shows it — on this box only `PulseCore/` and
doc↔code consistency are verifiable | `project.yml` is the source of truth;
`Pulse.xcodeproj` is generated, never hand-edited | scope discipline: no accounts, no
cloud sync, no analytics, no onboarding beyond permission prompts — when in doubt, cut
the feature, don't abstract it | views never import HealthKit/MusicKit/Spotify/
CoreLocation directly; they depend on protocols from `Pulse/Services/` | docs and
comments are plain sentences — no marketing tone, no filler, no "This class represents
a class that…"

## Commands (macOS, from repo root)

```
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Domain tests — any OS with a Swift 6+ toolchain, including this Linux box (`~/swift`):

```
cd PulseCore && swift test
```

## Toolchain (verified 2026-08-19)

| Tool | Version | Notes |
|---|---|---|
| Xcode | 27 | Current release; Xcode 26.3+ has agentic coding features |
| iOS SDK target | 26.0 | Deployment target. iOS 26.6.1 is the shipping release; iOS 27 is beta — do not target it |
| Swift | 6.x | Strict concurrency enabled |
| Project generation | xcodegen | `project.yml` is the source of truth. `Pulse.xcodeproj` is generated, never hand-edited |
| Dependencies | None yet | Spotify iOS SDK added later via SPM (see `docs/INTEGRATIONS.md`); keep it the only one |
| Linux verification | Swift 6.3 toolchain (`~/swift`) | `PulseCore/` is platform-free SwiftPM; `swift test` there runs on this box. Only `PulseCore/` is Linux-buildable — anything importing SwiftUI/SwiftData/HealthKit/MusicKit/CoreLocation is macOS/Xcode-only |

## Conventions

Types `UpperCamelCase`, meaning-first (`WorkoutSession`, not `SessionManager`) |
formatting: 4-space indent, 100-col soft limit, `swift-format` default style otherwise |
charts: Swift Charts only — no chart libraries | views in `Pulse/Features/<Feature>/`,
`@Model` classes in `Pulse/Domain/Models/`, pure logic in `Pulse/Domain/` or `PulseCore/`
| tests: Swift Testing (`import Testing`) — pure domain logic lives in `PulseCore/` with
its tests (Linux-verifiable); platform-bound tests (views, services) get a `PulseTests`
target back in xcodegen when they exist (none yet)

## Concurrency

UI is `@MainActor`. Services are `actor` or `final class` with async methods.
async/await only — no Combine, no callbacks where `await` works. Swift 6 strict
concurrency is enabled; keep types `Sendable`-clean rather than silencing diagnostics.

## PulseCore

Platform-free: pure Foundation, imports nothing Apple. Anything needing
SwiftUI/SwiftData/HealthKit/MusicKit/CoreLocation belongs in `Pulse/`. The app target
compiles `PulseCore/Sources/PulseCore` directly (see `sources:` in `project.yml`) —
there is exactly one copy of the domain sources; never duplicate it into `Pulse/`.

## Permissions & Info.plist

All usage strings, the HealthKit entitlement, and the Spotify URL scheme
(`pulse-spotify` + `LSApplicationQueriesSchemes`) live in `project.yml` (Info.plist
properties + entitlements); `Pulse/Info.plist` is generated from them. Adding or
changing a permission = edit `project.yml`, regenerate, update `docs/INTEGRATIONS.md`
in the same change.

## Git & CI

`master` is the working branch. Remote hosting (GitHub) enables the free CI path:
`.github/workflows/ios.yml` runs on `macos-26` — xcodegen generate, unsigned simulator
build of the app, PulseCore tests. Public repo = free macOS runners; private repo draws
from the 2,000 free Actions minutes/month at a 10× macOS multiplier (~200 build minutes).
Signed device builds still require a local Mac (free provisioning can't be exported to CI).
Plain commits; no push or PR workflow beyond CI.

## Workflow phases (agreed with owner)

1. **Ground layer** — docs + skeleton (complete; see `README.md` status).
2. **Audit / validate / verify** — check docs↔code↔permissions consistency, then
   build+test on macOS.
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
Pulse/               app sources (platform-bound: SwiftUI/SwiftData/HealthKit/…)
PulseCore/           platform-free SwiftPM package: domain logic + tests (Linux-verifiable)
```

## Autoimprovement

Suggest new rules here when owner feedback or a recurring mistake generalizes | when a
feature lands, update the `README.md` status and the relevant doc in the same change |
re-verify the toolchain table when Xcode/iOS/Swift versions move, and re-date it.
