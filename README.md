# Gym Twin

A native **iOS 18+ / watchOS 11+** app that is a *digital twin* of one specific gym for one
user. Store per-machine settings, track sets/reps/weights, sync workouts to Apple Health, and
log training from the Apple Watch — fully **offline-first**, no backend, no login, no cloud.

Built with **Swift 6 (strict concurrency), SwiftUI, SwiftData, HealthKit, WatchConnectivity**
and an **MVVM** architecture.

## Requirements

- Xcode 16+ (developed against Xcode 26.5)
- [XcodeGen](https://github.com/yonsson/XcodeGen) — `brew install xcodegen`

## Generate & build

```bash
# Generate the .xcodeproj from project.yml
xcodegen generate

# Build the iOS app
xcodebuild -scheme GymTwin -destination 'generic/platform=iOS Simulator' build

# Build the watchOS app
xcodebuild -scheme GymTwinWatch -destination 'generic/platform=watchOS Simulator' build

# Run the test suite (41 tests)
xcodebuild -scheme GymTwin -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Open `GymTwin.xcodeproj` in Xcode, then set your **Development Team** on the `GymTwin` and
`GymTwinWatch` targets (Signing & Capabilities) before running on a device. The App Group
`group.com.markusvaitl.gymtwin` and the HealthKit capability are already declared in the
entitlements.

## Architecture

```
GymTwinShared/   Source compiled into BOTH apps
  Models/        7 SwiftData @Model types (Gym → Area → Machine → Setting, Workout → Exercise → Set)
  Persistence/   PersistenceController (shared App Group store), AppGroup
  Services/      StorageService, WatchPayloads (Codable DTOs), WatchConnectivityService
  Shared/        DesignTokens (DS.*)

GymTwin/         iOS app
  App/           GymTwinApp, RootView (TabView), AppRouter
  Services/      WorkoutService (PRs/stats/streak/history), HealthKitService, SyncCoordinator
  ViewModels/    Dashboard, Machine, Gym, Workout, History, Settings
  Views/         Dashboard, Machines, Workout, History, Settings, Components (design kit)
  Persistence/   SampleData seeder
  Resources/     Assets.xcassets

GymTwinWatch/    watchOS app — standalone training (browse machines, log sets, live HR/energy)
GymTwinTests/    XCTest: models, WorkoutService, DTO round-trip, sample data
```

### Key design choices

- **Shared source, not a binary framework** — models and the SwiftData schema stay identical on
  both platforms.
- **WatchConnectivity carries Codable DTOs**, never `@Model` objects; the App Group store is the
  durable backing store. Completed watch workouts are de-duplicated by `Workout.id` on the phone.
- **History survives deletion** — `WorkoutExercise` references a machine by `machineID` +
  denormalized `machineName`, so removing a machine never erases past performance.
- **Derived, not duplicated** — personal records, "last session" and statistics are computed by
  `WorkoutService`, not stored.
- **Graceful persistence** — the store falls back from App Group → local → in-memory so a missing
  entitlement never crashes the app.

## Future extension points (declared, not implemented)

NFC/QR machine identification, Bluetooth machine sensors, AI workout recommendations, cloud sync,
and multi-user sharing are all reachable through the service/repository seams without reworking
the data model.
