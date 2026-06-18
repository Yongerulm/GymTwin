# CLAUDE.md — Gym Twin

Guidance for Claude Code (and humans) working in this repository.

## What this is

**Gym Twin** is a native **iOS 18+ / watchOS 11+** app: a *digital twin* of one or more specific gyms.
Store per-machine settings, track sets/reps/weights, get on-device AI coaching, scan machines via
NFC/QR, and sync workouts to Apple Health — **offline-first**, no backend required, no login.

Reference gym in the seed data: **Shanghai Racket Club (SRC)**.

## Tech stack

- **Swift 6** (strict concurrency), **SwiftUI**, **SwiftData**, **Observation** (`@Observable`)
- **HealthKit**, **WatchConnectivity**, **CoreNFC**, **VisionKit/AVFoundation** (QR)
- **WidgetKit** (home/lock-screen widgets), **App Intents** (Siri "Start Workout"), **ActivityKit** (in-workout Live Activity)
- **MVVM** architecture, offline-first
- Project generated with **XcodeGen** from `project.yml`
- Optional, abstracted seams: **OpenSearch** equipment repository, Apple Foundation Models / cloud LLM
  coach — both behind protocols, not required to run

## Build & run

The Xcode project is generated from `project.yml`. After changing files, schemes, or settings:

```bash
brew install xcodegen          # one-time
xcodegen generate              # regenerate GymTwin.xcodeproj after structural changes

# Build (use the full Xcode, not Command Line Tools)
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -scheme GymTwin      -destination 'generic/platform=iOS Simulator'    build
xcodebuild -scheme GymTwinWatch -destination 'generic/platform=watchOS Simulator' build

# Tests (unit)
xcodebuild -scheme GymTwin -destination 'platform=iOS Simulator,name=iPhone 17' test
```

- Signing team is baked into `project.yml` (`DEVELOPMENT_TEAM`). On-device runs need NFC + HealthKit
  capabilities (already in the entitlements) and a valid team.
- **`xcodegen generate` after adding/removing/renaming source files** — new files are not in the
  project until regenerated. (CI/automation should regenerate before building.)

## Targets & layout

```
GymTwinShared/        Source compiled into BOTH apps
  Models/             7 SwiftData @Model types: Gym -> GymArea -> Machine -> MachineSetting,
                      Workout -> WorkoutExercise -> WorkoutSet  (Machine has machineCode for NFC/QR)
  Catalog/            MachineDefinition (Codable equipment-library record)
  Persistence/        PersistenceController (App Group store, graceful fallback), AppGroup
  Services/           StorageService, WatchPayloads (Codable DTOs), WatchConnectivityService
  Shared/             DesignTokens (DS.*) — dark theme palette, spacing, radius, muscle colors/symbols/images

GymTwin/              iOS app
  App/                GymTwinApp, RootView (4 tabs), AppRouter, GymSelection (active gym)
  Services/
    WorkoutService    PRs / stats / streak / history (derived, not duplicated)
    HealthKitService  auth, workout write, body metrics + steps/sleep/VO2Max
    RecoveryService   deterministic recovery score + HRV-led daily readiness
    MuscleRecoveryService  per-muscle-group recovery % (volume-scaled window since last session)
    AI/               AIWorkoutCoach protocol, DeterministicWorkoutCoach (rules), CoachService (history bridge)
    Recognition/      MachineRecognitionService (code parser), NFCService, QRScannerView
    Repository/       MachineRepository protocol, LocalMachineRepository (bundled machines.json),
                      OpenSearchMachineRepository (stub; activates when configured)
  ViewModels/         Today, Gym, Machine, Workout, Progress, Settings, Plan, Admin, Recognition
  Views/              Today, Gym, Machines, Workout, Progress, History, Settings, Plan, Profile, Admin, Components
  Resources/          machines.json (9 SRC machines), Assets.xcassets (AppIcon, area-*, micon-* icons)
  App/                + StartWorkoutIntent + GymTwinShortcuts (App Intents / Siri)
  Services/           + WidgetSyncService (writes WidgetSnapshot, reloads timelines),
                        WorkoutLiveActivityController (start/update/end the Live Activity)
GymTwinShared/Widget/ WidgetSnapshot + WidgetSnapshotStore + WidgetIntentBridge (App Group hand-off),
                      WorkoutActivityAttributes (ActivityKit)
GymTwinWidgets/       iOS widget extension: ReadinessWidget (small/medium + lock-screen
                      accessories) + WorkoutLiveActivityWidget (Dynamic Island + lock screen)
GymTwinWatch/         watchOS app (standalone training, Digital Crown, HKWorkoutSession)
GymTwinTests/         XCTest (73 tests): models, WorkoutService, DTOs, sample data, AI coach, recognition, repository, muscle recovery
GymTwinUITests/       Screenshot UI test (navigates main screens, attaches screenshots)
branding/             Icon/art generation sources (gen.py uses Gemini; .gemini_key is gitignored)
```

## Key product flows

- **4 tabs:** Today, Gym, Progress, Settings. Workout runs as a full-screen flow over any tab.
- **Multi-gym:** `GymSelection` tracks the active gym (persisted). The Gym tab filters areas/machines
  to it and offers a switcher + "Add Gym"; the Plan generator builds from the selected gym's machines.
- **Workout = start empty, then scan:** "Start" opens an empty session. Inside it, **Scan** (NFC, with a
  manual code fallback for the Simulator) loads a machine — resolves the code, files it under the active
  gym, and opens set entry **pre-filled with predefined weights** plus the machine's settings, ready to
  adjust. "Repeat" copies the last set + starts the rest timer.
- **AI coach** (`DeterministicWorkoutCoach`): weight suggestion, progressive overload (+2.5 kg after 2
  on-target sessions), deload detection, split-plan generation. Swappable behind `AIWorkoutCoach`.

## Conventions

- View models: `@Observable @MainActor final class` with `bind(_ context:)` / `refresh()`.
- Top-level tab views: no-arg `init()`, own `NavigationStack`.
- **Design system only** — never hardcode colors/spacing. Use `DS.Spacing/Radius/Palette/Muscle/Motion`
  and the component library (`SurfaceCard`, `MachineCard`, `MachineThumbnail`, `MetricCard`,
  `ProgressRingCard`, `MachineSettingChip`, AI cards, `WorkoutControlStepper`, `RestTimerView`, ...).
- **Dark-locked** premium theme: deep anthracite (`DS.Palette.background`) + `GymBackground` glow;
  cards on `DS.Palette.surface`. `UIUserInterfaceStyle = Dark`.
- Machine thumbnails resolve to schematic equipment icons via `MachineArt` (`micon-*` assets), falling
  back to the muscle SF Symbol; a user photo always wins.
- Derived data (PRs, stats, "last session") is computed via `WorkoutService`, never duplicated into state.
- One type per file; files < ~400 lines.

## Important constraints / gotchas

- **NFC and the camera only work on a real device** — the Simulator has neither. The scan sheet always
  offers a manual machine-code field as a fallback.
- **Apple Foundation Models** require an Apple-Intelligence-capable device; the deterministic coach is
  the always-available default.
- **OpenSearch** is optional: `OpenSearchMachineRepository` throws `.notConfigured` without
  `OPENSEARCH_URL`, and the app transparently uses `LocalMachineRepository`. Index mapping lives in
  `OpenSearchConfig.indexMapping`.
- **Secrets:** never commit keys. `branding/.gemini_key` (Gemini image generation) is gitignored.
- **`-uitest-no-health`** launch argument suppresses the HealthKit permission sheet during UI tests.

## When making changes

1. Edit source under the appropriate target.
2. If files were added/removed/renamed: `xcodegen generate`.
3. Build the iOS scheme (and the Watch scheme if shared/watch code changed).
4. Run the unit tests; keep them green.
5. Commit and push so GitHub always reflects the current program.
