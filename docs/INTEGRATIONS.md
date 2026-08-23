# Integrations

## HealthKit

- Capability: HealthKit; `Info.plist` keys: `NSHealthShareUsageDescription` (read),
  `NSHealthUpdateUsageDescription` (write workouts/energy). Exact strings in `project.yml`.
- Request **all** read types + workout write at first launch, once; Settings shows grant status
  and an "Open Health settings" re-prompt link. Do not gate the app on the grant — workouts
  log fine without HealthKit.
- AirPods Pro 3 heart rate needs **no direct integration**: the sensor writes to HealthKit and
  Pulse reads `.heartRate` like any other source. Per-workout HR = anchored query over
  `startedAt…endedAt`, avg + peak.
- Simulator verification: Health app has sample data; for device pass, one real workout with
  AirPods Pro 3 worn.

## Apple Music (MusicKit)

- No capability toggles; requires `NSAppleMusicUsageDescription` ("Media & Apple Music" usage).
- Permission: `MusicAuthorization.request()` at first playlist pick, not at launch.
- **Implemented:** library playlist fetch (`MusicLibraryRequest<Playlist>`) and playback
  via `ApplicationMusicPlayer`. Untested pending macOS build — the
  `ApplicationMusicPlayer.Queue(for:)` call in particular needs simulator confirmation.
- Developer Program membership ($99/yr) required for catalog API — note in Settings if
  unauthorized; playback of user's own library still works with standard signing.

## Location (gym arrival)

- Framework: CoreLocation region monitoring + UserNotifications. No third-party dependency.
- Permission model: request **When In Use** at first gym save. Region-monitoring events that
  launch the app from the background require **Always** — Settings shows a one-tap upgrade
  prompt and explains why ("so Pulse can notice you arrived at the gym"). App works fully
  without it; only arrival prompts degrade.
- Flow: save gym → register `CLCircularRegion` (id = gym UUID, radius default 100 m).
  `didEnterRegion` → local notification → tap deep-links to session screen.
- iOS limits ~20 monitored regions per app; personal use won't hit it, but re-registration
  keeps the most recently used gyms monitored.

## Spotify

- Status: **stubbed** (`SpotifyService` returns `notImplemented`). The UI handles it
  gracefully: playlists attach from Apple Music today; the picker shows a one-line note.
- SDK: `https://github.com/spotify/ios-sdk` via SPM (add to `project.yml` when the music
  feature starts; kept out of the skeleton so generation stays dependency-free).
- Developer dashboard app: redirect URI `pulse-spotify://callback`, URL scheme
  `pulse-spotify` registered in `project.yml`; `LSApplicationQueriesSchemes: [spotify]` to
  detect the installed app.
- Scopes: `playlist-read-private`, `app-remote-control` (playback), `user-read-email` minimal.
- Token exchange: SDK's recommended pattern is a small token-swap endpoint; for personal use,
  PKCE on-device is acceptable and avoids running a server. Decision deferred to the music
  build; documented here so it isn't re-litigated in code review.
- Failure mode: Spotify app not installed / token expired → banner "Open Spotify and try again",
  workout continues unaffected.

## Distribution (no Mac): App Store Connect API + TestFlight

The owner has an Apple Developer account. Everything signing-related is automated
through the App Store Connect API from Linux — no Xcode, no Mac:

1. **One-time setup:** create an API key in App Store Connect (Users and Access →
   Integrations → App Store Connect API, role Admin or App Manager), then run
   `scripts/asc-setup.sh`. It registers the bundle ID (`com.gorxfitness.pulse`),
   enables HealthKit on it, creates the App record, an IOS_DISTRIBUTION certificate
   (CSR generated locally with openssl), and an App Store provisioning profile —
   then prints the exact `gh secret set` commands.
2. **Per-build:** `.github/workflows/testflight.yml` (manual dispatch) imports the
   certificate + profile, archives, exports the IPA with
   `scripts/ExportOptions.plist`, and uploads with `xcrun altool` using the same API
   key. Build lands in TestFlight after Apple processing.
3. First TestFlight build requires answering export compliance in App Store Connect
   (standard encryption; answer the questions for a fitness app with no crypto of
   its own). Internal testing needs no beta review; external does.

Secrets: `ASC_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY` (base64 .p8),
`DIST_P12` (base64), `P12_PASSWORD`, `PROFILE` (base64 mobileprovision).

## Permission strings (single source of truth)

```
NSHealthShareUsageDescription      Pulse reads your heart rate, workouts, weight and height to show progress.
NSHealthUpdateUsageDescription     Pulse saves the workouts you log to Health.
NSAppleMusicUsageDescription       Pulse links playlists from your Apple Music library to workouts.
NSLocationWhenInUseUsageDescription    Pulse saves your gym locations on a map.
NSLocationAlwaysAndWhenInUseUsageDescription  With Always access, Pulse can notice when you arrive at the gym and offer to start your workout.
```
