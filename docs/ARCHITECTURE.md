# Gym Twin / FitPilot AI — Architecture & Implementation Roadmap

Reference for engineers. Pairs with [`CLAUDE.md`](../CLAUDE.md) (build + conventions).
This document maps the product vision to **what is already implemented** vs **what
remains**, documents the architecture, and gives a phased roadmap with status.

> **Naming:** repo/target = `GymTwin`; current display name = *FitPilot AI*. The
> two names refer to the same product.

---

## 1. Status at a glance (vision → implementation)

| Capability | Status | Where |
|---|---|---|
| SwiftUI · SwiftData · Observation · MVVM · offline-first | done | whole app |
| Dark-mode-first premium design system + `GymBackground` glow | done | `DesignTokens`, `Views/Components` |
| 5-tab IA: Dashboard · Workouts · Scan · Analytics · Profile | done | `RootView`, `AppRouter` |
| NFC + QR machine recognition (lfconnect format) | done | `Services/Recognition` |
| Scan → resolve → load machine → prefill weights | done | `WorkoutFlowView.loadScannedMachine` |
| Workout-aware NFC (scan loads the **active plan's** target) | done | `WorkoutFlowView.activePlanTarget` |
| Hands-free / continuous scan re-arm during a session | done | `WorkoutFlowView.armContinuousScan` |
| Manual training plans (selected machines + targets) | done | `WorkoutPlan`, `PlansListView` |
| Deterministic progression (+2.5 kg after 2 on-target, deload) | done | `DeterministicWorkoutCoach` |
| Advanced set types (warmup/working/drop/AMRAP/EMOM/Tabata/…) | done | `WorkoutSetType` |
| Exercise library (1108 movements) + search/filter | done | `Exercise`, `exercises.json` |
| 15-machine equipment catalog | done | `machines.json`, `LocalMachineRepository` |
| Premium per-machine icons (muscle-group coloured, AI-generated) | done | `mach-*` assets, `MachineArt` |
| HealthKit read (weight/HR/steps/sleep/VO₂Max/**HRV**/**resting HR**) + write workout | done | `HealthKitService` |
| Recovery + **HRV-led daily Readiness** score + dashboard card | done | `RecoveryService`, Progress “Today's Readiness” |
| Apple Watch app (standalone, HKWorkoutSession, Digital Crown) | done | `GymTwinWatch` |
| OpenSearch repository abstraction (stub, index mapping) | done | `OpenSearchMachineRepository` |
| Admin panel (machine CRUD, QR/NFC mappings, sync) | done | `AdminPanelView` |
| Multi-gym digital twin (Gym → Area → Machine) | done | models + `GymSelection` |
| 60 unit tests | done | `GymTwinTests` |
| **Guided plan-stepping mode** (auto-advance through plan, rest cues) | partial | see §5 |
| **Muscle-specific recovery** (per-group fatigue) | todo | see §5 |
| **Invisible / no-UI NFC** | NOT POSSIBLE on iOS | see §4 |
| Sign in with Apple · CloudKit · StoreKit · Widgets · App Intents | todo | needs paid dev account (have it) |

**Bottom line:** the NFC-first training loop, AI progression, readiness, plans,
exercise library, watch app and premium icons are **shipped**. The remaining
product-defining work is *guided mode polish*, *muscle-specific recovery*, the
*Apple-ecosystem surfaces* (widgets/Siri/CloudKit/StoreKit), and Apple
Intelligence — none blocked by architecture.

---

## 2. Technical architecture

```
GymTwinShared/   (compiled into iOS + watch)
  Models/        Gym, GymArea, Machine, MachineSetting,
                 Workout, WorkoutExercise, WorkoutSet (+ WorkoutSetType),
                 WorkoutPlan, PlanExercise, Exercise (library)
  Catalog/       MachineDefinition (equipment-library record)
  Persistence/   PersistenceController (App Group store, graceful fallback)
  Services/      StorageService, WatchPayloads (DTOs), WatchConnectivityService
  Shared/        DesignTokens (DS.*) — palette, spacing, muscle colour/symbol/image

GymTwin/         iOS app
  App/           GymTwinApp, RootView (5 tabs), AppRouter, GymSelection
  Services/
    WorkoutService     derived stats / PRs / streak / history
    HealthKitService   auth + read (incl. HRV, resting HR) + workout write
    RecoveryService    recovery score + HRV-led readiness (ReadinessBand)
    AI/                AIWorkoutCoach protocol, DeterministicWorkoutCoach, CoachService
    Recognition/       MachineRecognitionService, NFCService, QRScannerView
    Repository/        MachineRepository (Local + OpenSearch stub)
    ExerciseSeeder     seeds the 1108-movement library once
  ViewModels/    Today, Gym, Machine, Workout, Progress, Settings, Plan, Admin, Recognition, Exercise
  Views/         Dashboard(Today), Workouts, Scan, Analytics(Progress), Profile(Settings),
                 Gym, Machines, Plan, Exercise library, Components
GymTwinWatch/    watch app
GymTwinTests/    XCTest
```

**Patterns:** MVVM (`@Observable @MainActor` view models, `bind(context)`/`refresh()`),
Repository (machine data behind `MachineRepository`), protocol-seam AI
(`AIWorkoutCoach`), DTO sync across WatchConnectivity, derived-not-duplicated
analytics. Offline-first: everything works with no network; OpenSearch / cloud are
optional adapters behind protocols.

**Data flow (the core loop):**
`Scan (NFC/QR/manual) → MachineRecognitionService.parseMachineCode →
LocalMachineRepository.machine(forCode:) → find/create user Machine (active gym) →
activePlanTarget OR CoachService.nextSet → WorkoutSetEntryView prefilled → log set
→ WorkoutDTO → WorkoutService.persist → HealthKit write → WatchConnectivity sync.`

---

## 3. NFC architecture (as built)

- `NFCService` wraps `NFCNDEFReaderSession`; `MachineRecognitionService` parses
  URL/Text/NDEF payloads and lfconnect QR URLs to a `machineCode`.
- During a session the reader **auto-re-arms** (`armContinuousScan`) so the user
  taps machine → loads next exercise without pressing a button each time.
- The visible affordance is a **minimal NFC button**; the big custom scan sheet was
  removed. Simulator fallback = a small machine-code text field.

---

## 4. Reality check — "Invisible NFC Mode" is NOT possible on iOS

The spec's Feature 3 ("the NFC popup/bottom sheet must never appear … No popup. No
modal. No user interaction") **cannot be implemented on iOS as written.** Apple does
not permit silent foreground NFC reading:

- `NFCNDEFReaderSession` / `NFCTagReaderSession` **always** present the system
  "Ready to Scan" sheet. There is no API to read a tag in the foreground without it.
- The only "background" NFC is **OS-level background tag reading**: when the app is
  *not* in the foreground, iOS reads an NDEF tag and shows a **system notification**;
  tapping it launches the app via a universal link. Still a system surface, still a tap.

**Closest feasible UX (recommended), already partly built:**
1. Workout active → reader auto-re-armed (`armContinuousScan`). User taps phone to a
   tag; the brief system sheet appears, reads, dismisses automatically.
2. On detect → **success haptic** + a small in-app **"✓ Chest Press" banner** + auto
   transition to the exercise screen. (Banner + haptic: to add.)
3. Optionally publish each machine's tag as a **universal-link NDEF** so a locked /
   backgrounded phone tapped on a tag deep-links straight into that exercise.

This delivers the *feel* of "tap and it just opens" within Apple's rules.
**Decision needed:** accept the brief system sheet — it is the only Apple-compliant
option; there is no way around it.

---

## 5. Remaining product work (designs ready to build)

### Guided Workout Mode (Feature 1) — partial
Have: plans with ordered exercises + targets; scan loads the active plan's target.
To add: a **guided session driver** that, given an active plan, tracks the current
exercise/set, shows *Current Exercise · Set x/N · target reps · weight · rest timer*,
auto-starts the rest timer on “complete set”, and advances to the next planned
exercise (or jumps to whichever machine is scanned). State lives in
`WorkoutViewModel` (add `activePlan`, `currentExerciseIndex`, `currentSetIndex`).

### Muscle-specific recovery (Feature 6) — todo
Compute a per-muscle **fatigue** value from recent volume per muscle group
(`Exercise.primaryMuscles` × set volume, time-decayed) and combine with global
readiness. Surface "Chest: fatigued / Legs: recovered" and let the coach reduce
volume for fatigued groups. New: `MuscleRecoveryService` + a Recovery section.

### Apple ecosystem surfaces (have paid dev account)
- **WidgetKit**: today's readiness + next planned workout.
- **App Intents / Siri**: "Start Push Day", "Log 60 kg × 10".
- **ActivityKit Live Activity**: active set + rest timer on the lock screen.
- **CloudKit**: mirror the SwiftData store for multi-device.
- **StoreKit 2**: premium gate (AI coach, advanced analytics, recovery).

### Apple Intelligence (Feature 13)
Behind the existing `AIWorkoutCoach` seam: add a `FoundationModelsCoach` (on-device
`FoundationModels`) for natural-language coaching / plan generation, falling back to
`DeterministicWorkoutCoach`. No call-site changes.

---

## 6. Implementation roadmap (phased) with current status

| Phase | Scope | Status |
|---|---|---|
| **1 — Core workout system** | models, logging, set types, progression | done |
| **2 — NFC integration** | CoreNFC, QR, recognition pipeline, minimal button | done |
| **3 — Workout-aware NFC** | scan loads active-plan target; continuous re-arm | done (+ guided-mode driver = next) |
| **4 — AI recovery coach** | HealthKit HRV/sleep/RHR, readiness score + card | core done; **muscle-specific recovery = next** |
| **5 — Apple Watch** | standalone watch app, HKWorkoutSession, set logging | done (set-type parity + guided mode = polish) |
| **6 — Apple Intelligence** | FoundationModels coach behind `AIWorkoutCoach` | todo |
| **7 — Machine library expansion** | scale catalog toward 1000+, premium icons | catalog 15 + 1108 exercises done; expand machines + icon set |
| **8 — Production hardening** | CloudKit, StoreKit, Widgets, App Intents, CI, perf | todo (paid dev account available) |

**Recommended next build order (each shippable, commit+push per step):**
1. Guided Workout Mode driver (completes Feature 1, biggest UX win).
2. Detect-banner + haptic for NFC (the feasible part of "invisible NFC").
3. Muscle-specific recovery (`MuscleRecoveryService` + UI).
4. Widgets + App Intents + Live Activity.
5. CloudKit + StoreKit gating.
6. FoundationModels coach.

---

## 7. Performance & quality targets (Feature 12)
Launch < 1 s · NFC round-trip is bounded by Apple's sheet, not our code · 60 fps
(compositor-friendly animations only) · no main-thread blocking (HealthKit/NFC/repo
are async) · offline-first with local caching · keep the 60-test suite green.
