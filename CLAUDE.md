# DeepState — Apple Watch Dive Computer

## What Is This

DeepState is a recreational dive computer app targeting Apple Watch Ultra, with an iOS companion app. It implements the Bühlmann ZHL-16C decompression algorithm with configurable gradient factors, real-time NDL/deco tracking, gas management (Air + Nitrox), safety stop logic, and tissue saturation monitoring.

**Not yet on the App Store.** This is a development build with simulated dive data. Real depth sensing requires the restricted `com.apple.developer.coremotion.water-submersion` entitlement from Apple.

---

## Build & Run

**Prerequisites:** Xcode 16+, macOS 14+, XcodeGen (`brew install xcodegen`)

```bash
cd ~/Source/DeepState
xcodegen generate                   # creates DeepState.xcodeproj from project.yml
open DeepState.xcodeproj
```

- **iOS target** builds on iOS 17+ simulator (tested on iPhone 17 Pro sim)
- **watchOS target** requires watchOS SDK installed via Xcode > Settings > Components
- **DiveCore tests:** `cd DiveCore && swift test` (31 tests, all passing)
- **Debug builds** automatically set `SIMULATE_DIVE=1` flag — mock sensor auto-runs a 28-minute scripted dive profile
- Set your Apple Developer Team ID on both targets before building to device
- `CODE_SIGNING_ALLOWED=NO` works for simulator builds

---

## Architecture Overview

```
DeepState/
├── project.yml                    # XcodeGen spec (source of truth for xcodeproj)
├── DiveCore/                      # Swift Package — pure logic, NO UI
│   ├── Package.swift              # platforms: macOS 14, iOS 17, watchOS 10
│   ├── Sources/DiveCore/
│   │   ├── Models/                # Data types and SwiftData persistence
│   │   ├── Engine/                # Decompression algorithms and session management
│   │   └── Sensors/               # Depth sensor abstraction + mock
│   └── Tests/DiveCoreTests/       # 31 unit tests
├── DeepStateWatch/                # watchOS app target (SwiftUI)
│   ├── Views/                     # Pre-dive, dive, detail, post-dive screens
│   ├── DiveViewModel.swift        # @Observable wrapper around DiveSessionManager
│   └── DiveSensorBridge.swift     # Bridges DiveSensorProtocol to SwiftUI
├── DeepStateApp/                  # iOS companion app target (SwiftUI)
│   ├── Views/                     # Dive log, planner, settings
│   ├── WatchConnectivityManager.swift
│   └── HealthKitManager.swift
```

### Three-Layer Architecture

1. **DiveCore** (Swift Package) — All dive logic. Zero UI imports. Testable in isolation. Both app targets depend on this.
2. **DeepStateWatch** — watchOS SwiftUI app. Consumes DiveCore via `DiveViewModel` (@Observable wrapper). Displays real-time dive data, fires haptics.
3. **DeepStateApp** — iOS SwiftUI app. Consumes DiveCore for dive planning calculations and SwiftData models for log display.

### Key Design Decisions

- **DiveSessionManager is NOT observable.** It's a plain class with `private(set)` properties. The watchOS app wraps it in `DiveViewModel` (@Observable) which mirrors state via `syncState()` after every mutation. This keeps DiveCore free of UI framework dependencies.
- **SafetyStopManager uses an enum state machine:** `notRequired → pending → inProgress(remaining:) → completed/skipped`. Not a simple bool flag.
- **SwiftData models live in DiveCore** (DiveSession, DepthSample, DiveSettings) so both targets share the same schema.
- **No third-party dependencies.** Only Apple frameworks: CoreMotion, HealthKit, SwiftData, Swift Charts, WatchConnectivity.

---

## DiveCore — Detailed API Reference

### Models

**DivePhase** — `enum DivePhase: String, Codable, CaseIterable, Sendable`
- Cases: `surface`, `predive`, `descending`, `atDepth`, `ascending`, `safetyStop`, `surfaceInterval`

**GasMix** — `struct GasMix: Codable, Sendable, Equatable`
- Properties: `o2Fraction`, `n2Fraction`, `heFraction` (all Double)
- Presets: `.air` (21/79/0), `.ean32` (32/68/0), `.ean36` (36/64/0)
- Factory: `GasMix.nitrox(o2Percent: Int)` — validates 21-40%
- Computed: `isNitrox` (o2 > 21% and no helium)

**DiveSettings** — `@Model class` (SwiftData)
- `unitSystem: String` ("metric"/"imperial"), `defaultO2Percent: Int`, `gfLow: Double`, `gfHigh: Double`, `ppO2Max: Double`, `ascentRateWarning: Double`, `ascentRateCritical: Double`, `targetAscentRate: Double`

**DiveSession** — `@Model class` (SwiftData)
- Core: `id: UUID`, `startDate: Date`, `endDate: Date?`, `maxDepth`, `avgDepth`, `duration`, `minTemp`, `maxTemp`
- Gas config: `o2Percent: Int`, `gfLow`, `gfHigh`
- Tracking: `phaseHistory: [String]`, `cnsPercent`, `otuTotal`, `tissueLoadingAtEnd: [Double]`
- Relationship: `depthSamples: [DepthSample]?` (cascade delete)

**DepthSample** — `@Model class` (SwiftData)
- `timestamp: Date`, `depth: Double`, `temperature: Double?`, `ndl: Int?`, `ceilingDepth: Double?`, `ascentRate: Double?`
- Inverse: `diveSession: DiveSession?`

### Engine

**BuhlmannEngine** — `class BuhlmannEngine`
The core decompression algorithm. Implements Bühlmann ZHL-16C with 16 tissue compartments tracking N2 and He partial pressures.

- `init(gfLow: Double = 0.40, gfHigh: Double = 0.85)` — initializes tissues at surface saturation
- `tissueStates: [TissueState]` — 16 compartments, each with `pN2` and `pHe`
- `gfLow`, `gfHigh`, `surfacePressure` (default 1.013 bar)
- `updateTissues(depth:gasMix:timeInterval:)` — Schreiner equation per compartment. Ambient pressure = surfacePressure + depth/10. Accounts for water vapor pressure (0.0627 bar).
- `ndl(depth:gasMix:) -> Int` — No-decompression limit in minutes. Simulates on a COPY of tissue states, incrementing 1 minute at a time up to 999. Returns 0 if already in deco.
- `ceilingDepth(gfNow:) -> Double` — Minimum safe ascent depth in meters. Max across all compartments of tolerated ambient pressure converted to depth.
- `gfAtDepth(depth:) -> Double` — Linear interpolation: gfLow at ceiling, gfHigh at surface.
- `decoStops(gasMix:) -> [(depth: Double, time: Int)]` — Required stops at 3m increments from ceiling to surface.
- `resetToSurface()` — Reset all tissues to surface N2 saturation (ppN2 = 0.7808 * (1.013 - 0.0627))
- `tissueLoadingPercentages() -> [Double]` — 0-100+% loading relative to M-value at surface

ZHL-16C compartment constants (halfTimeN2 in minutes): 4, 8, 12.5, 18.5, 27, 38.3, 54.3, 77, 109, 146, 187, 239, 305, 390, 498, 635

**GasCalculator** — `struct GasCalculator` (all static methods)
- `mod(gasMix:ppO2Max:) -> Double` — Maximum Operating Depth in meters
- `ppO2(depth:gasMix:) -> Double` — Partial pressure of O2 at depth
- `cnsPerMinute(ppO2:) -> Double` — CNS toxicity rate per NOAA limits (0 below 0.6 ppO2)
- `updateCNS(currentCNS:ppO2:timeInterval:) -> Double` — Accumulate CNS percentage
- `updateOTU(currentOTU:ppO2:timeInterval:) -> Double` — Oxygen Toxicity Units (threshold 0.5 ppO2)
- `ead(depth:gasMix:) -> Double` — Equivalent Air Depth for nitrox

**AscentRateMonitor** — `struct AscentRateMonitor`
- `evaluate(previousDepth:currentDepth:timeInterval:) -> (rate: Double, status: AscentRateStatus)`
- `AscentRateStatus` enum: `.safe`, `.warning` (>=12 m/min), `.critical` (>=18 m/min)
- Default thresholds: target 9, warning 12, critical 18 (all m/min)

**DepthLimits** — `enum DepthLimits` (non-configurable safety constants)
- `maxOperatingDepth: 40.0`, `defaultDepthAlarm: 38.0`, `warningDepth: 39.0`, `criticalDepth: 40.0`
- `DepthLimitStatus` enum: `.safe`, `.approachingLimit`, `.maxDepthWarning`, `.depthLimitReached`
- `evaluate(depth:depthAlarm:) -> DepthLimitStatus`

**TissueStatePersistence** — `class TissueStatePersistence` (crash recovery)
- `persist(manager:)` — saves full dive state to JSON in documents directory
- `loadPersistedState() -> PersistedDiveState?`
- `hasInterruptedSession() -> Bool` — checks if active dive phase was persisted
- `clearPersistedState()` — call when dive ends normally
- `restore(from:) -> DiveSessionManager` — reconstructs manager from persisted state

**DiveHealthEvent** — `struct DiveHealthEvent: Codable, Sendable`
- 12 event types: sensorUnavailable, sensorRestored, sensorDataStale, backgroundInterruption, backgroundResumed, depthLimitWarning, depthLimitReached, ndlAnomaly, phaseTransition, safetyStopStarted, safetyStopCompleted, safetyStopSkipped

**SafetyStopManager** — `class SafetyStopManager`
- State machine: `SafetyStopState` — `.notRequired`, `.pending`, `.inProgress(remaining:)`, `.completed`, `.skipped`
- `update(currentDepth:maxDepth:timeInterval:)` — drives state transitions
- `isAtSafetyStop: Bool`, `remainingTime: TimeInterval`, `safetyStopRequired: Bool`
- Triggers when `maxDepth >= 10m` and diver reaches safety stop zone (5m ± 1.5m tolerance)
- Timer pauses/resets if diver drops below tolerance. Skips if diver ascends past zone.

**DiveSessionManager** — `class DiveSessionManager`
The orchestrator. NOT observable — plain class with `private(set)` properties.

- `init(gasMix: GasMix = .air, gfLow: Double = 0.40, gfHigh: Double = 0.85)`
- Exposes: `phase`, `currentDepth`, `maxDepth`, `averageDepth`, `temperature`, `minTemperature`, `elapsedTime`, `ndl`, `ceilingDepth`, `ascentRate`, `ascentRateStatus`, `cnsPercent`, `otuTotal`, `ppO2`, `surfaceIntervalStart`
- Public sub-objects: `gasMix: GasMix`, `engine: BuhlmannEngine`, `safetyStopManager: SafetyStopManager`, `ascentRateMonitor: AscentRateMonitor`
- `startDive()` — transitions to `.descending`, resets all state, starts timing
- `updateDepth(_ depth:)` — main update loop: ascent rate eval → tissue update → NDL/ceiling recalc → CNS/OTU → safety stop → phase detection
- `updateTemperature(_ temp:)` — tracks current and min temperature
- `endDive()` — transitions to `.surfaceInterval`
- `resetForNewDive()` — transitions to `.surface`
- Computed: `tissueLoadingPercent`, `gasDescription`, `gfDescription`
- Phase detection logic: depth increasing = descending, depth decreasing = ascending, at safety stop = safetyStop, depth < 0.5m for 5s = auto-end

### Sensors

**DiveSensorProtocol** — protocol for depth data sources
- `delegate: DiveSensorDelegate?`, `isAvailable: Bool`, `startMonitoring()`, `stopMonitoring()`
- Delegate callbacks: `didUpdateDepth(_:temperature:)`, `didChangeSubmersionState(_:)`, `didEncounterError(_:)`

**MockDiveSensor** — implements DiveSensorProtocol with a scripted profile
- 28-minute dive: descent to 18m (2min) → bottom time (20min) → ascent with safety stop at 5m (3min) → surface
- Linear interpolation between waypoints, 1-second tick rate
- Temperature: 28°C surface → 22°C at 18m (linear)
- Auto-starts when `SIMULATE_DIVE` flag is set

**SimulatedDiveSession** — ObservableObject wrapper around MockDiveSensor for SwiftUI previews

---

## watchOS App — View Architecture

**ContentView** — Root view, switches on dive phase:
- `.surface` → PreDiveView
- `.descending/.atDepth/.ascending/.safetyStop` → TabView (vertical page, Digital Crown scroll) containing DiveView + DetailView
- `.surfaceInterval` → PostDiveView

**DiveViewModel** — `@Observable` wrapper around `DiveSessionManager`. Mirrors all properties into observable storage. Calls `syncState()` after every mutation to trigger SwiftUI updates. This exists because DiveSessionManager intentionally has no UI framework dependencies.

**DiveSensorBridge** — `@Observable` class implementing `DiveSensorDelegate`. Bridges MockDiveSensor (or future CMWaterSubmersionManager) to SwiftUI. Publishes depth, temperature, isSubmerged.

**PreDiveView** — Gas selection (Air/EAN32/EAN36/Custom + O2% stepper), GF selection (Default 40/85, Conservative 30/70, Custom), target depth, START DIVE button.

**DiveView** — Primary underwater display (black background, optimized for readability):
- Layout: top row (elapsed MM:SS | NDL/DECO), center (depth in 52pt bold rounded, color-coded), bottom row (temp | ascent rate | battery placeholder)
- Color coding: green (safe), yellow (NDL <= 5 or ascent warning), red (in deco or critical ascent)
- Safety stop overlay: progress ring with countdown, semi-transparent black background
- Haptics via WKInterfaceDevice: `.notification` for NDL warning, `.failure` for deco, `.directionUp` for ascent warning, `.stop` for critical ascent, `.click` for safety stop start

**DetailView** — Secondary stats: max/avg depth, CNS% with progress bar (green/yellow/red), ppO2 with color coding, gas mix, GF, compass placeholder.

**PostDiveView** — Summary (max depth, duration, avg depth, min temp), 16-compartment tissue loading bar chart, surface interval timer, SAVE (to SwiftData) and NEW DIVE buttons.

---

## iOS App — View Architecture

**MainTabView** — 3 tabs: Dive Log, Planner, Settings

**DiveLogListView** — `@Query` fetching DiveSessions sorted by startDate desc. Shows dive number, date, max depth, duration, gas. Swipe to delete. Empty state with ContentUnavailableView.

**DiveDetailView** — Dive detail with:
- Summary card (2x2 grid + gas/GF/CNS/OTU)
- Depth profile chart (Swift Charts LineMark, inverted Y-axis, area gradient fill, max depth annotation, safety stop rule mark)
- Temperature chart (orange theme)
- Tissue loading bars (16 compartments, color-coded)
- Phase timeline

**DivePlannerView** — Interactive planner: target depth stepper, gas picker, GF steppers. Live-computed: NDL (creates local BuhlmannEngine), MOD, ppO2, EAD. Red warning if depth > MOD. Simulated square profile with time estimates.

**SettingsView** — Form: unit system, default gas, GF with presets, ppO2 max, ascent rates. Persists to SwiftData. Red disclaimer: "Not certified for life-safety use."

**WatchConnectivityManager** — `@Observable`, `WCSessionDelegate`. Sends settings to watch, receives dive session data and persists to SwiftData.

**HealthKitManager** — `@Observable`. Requests authorization for workouts + underwaterDepth + waterTemperature. Saves DiveSessions as `.underwaterDiving` HKWorkouts. Queries past dive workouts.

---

## Entitlements

| Entitlement | Target | Notes |
|---|---|---|
| `com.apple.developer.healthkit` | iOS + watchOS | Self-provisioned |
| `UIBackgroundModes: workout-processing` | watchOS | In Info.plist |
| `com.apple.developer.coremotion.water-submersion` | watchOS | **Requires Apple approval** — not yet provisioned. App uses MockDiveSensor until granted. |

---

## Test Suite (31 tests, all passing)

**BuhlmannEngineTests** (10 tests):
- Surface saturation validation (ppN2 ~0.7476 bar)
- NDL spot-checks: 10m (>200min), 18m (~50-60min, PADI table: 56), 30m (~20min), 40m (~8-10min)
- Ceiling depth 0 at surface, tissue loading increases after depth exposure
- Conservative GF (30/70) produces shorter NDL than default (40/85)
- Deco stops generated after exceeding NDL at 40m
- Reset returns tissues to surface saturation

**GasCalculatorTests** (11 tests):
- MOD: air ~56.7m, EAN32 ~33.75m, EAN36 ~28.9m
- ppO2: air@30m = 0.84, air@surface = 0.21
- CNS increases above 0.6 ppO2, zero below
- OTU increases above 0.5 ppO2, zero below
- EAD: air at any depth = same depth; nitrox at 30m < 30m

**SafetyStopTests** (5 tests):
- Required after dive > 10m, not required for shallow
- Countdown at 5m, pauses when too deep, completes after 180s

**AscentRateTests** (5 tests):
- Safe < 12 m/min, warning >= 12, critical >= 18, descent always safe

---

## Safety Features (Apple Entitlement Application Compliance)

All features claimed in the Apple water submersion entitlement application are implemented:

**Depth Limit Enforcement (5 overlapping mechanisms):**
- `DepthLimits` enum with hard-coded non-configurable 40m max operating depth
- Onboarding: first-launch acknowledgment of 40m limit (UserDefaults gate)
- Pre-dive: persistent "Operating depth: 40m / 130ft max" reminder
- Depth alarm at 38m (configurable) with yellow banner + haptic
- Full-screen MAX DEPTH WARNING at 39m with red background + continuous haptic
- DEPTH LIMIT REACHED at 40m: NDL terminated, full-screen red, "ASCEND NOW"

**Fault Tolerance:**
- `WKExtendedRuntimeSession` for background dive tracking
- Tissue state persisted to disk every 5 seconds via `TissueStatePersistence`
- Session recovery on app crash: `SessionRecoveryView` with resume/end options
- `DiveHealthEvent` logging (12 event types: sensor, phase, depth limit, NDL anomaly, etc.)
- `sessionIntegrityScore` computed post-dive (deductions per event type)

**Sensor Safety:**
- Stale sensor data detection (>10 seconds without update)
- NDL blanked and "SENSOR DATA STALE" overlay when stale
- `SENSOR UNAVAILABLE` state in DiveSensorBridge

**User Safety:**
- 3-category feedback system in iOS app (General, Bug Report, Safety Incident P0)
- Version check stub for minimum safe version enforcement
- EN13319 water density standard (depth/10.0 pressure conversion)
- Schreiner equation (exact analytical solution, not approximation)

---

## Known Gaps / TODO

1. **watchOS build unverified** — needs watchOS SDK installed in Xcode
2. **No WatchConnectivity on watch side** — iOS has WatchConnectivityManager but watch has no counterpart to send dive data back to phone
3. **DiveSessionManager state machine tests** — phase detection and full update pipeline need more test coverage
4. **No asset catalogs** — no app icons for either target
5. **No CloudKit sync** — spec mentioned it but not implemented; SwiftData is local-only
6. **No end-to-end integration test** — MockDiveSensor → DiveSessionManager → DiveSession output pipeline not validated
7. **Imperial units** — setting exists but no conversion logic in views
8. **Real CMWaterSubmersionManager** — blocked on Apple entitlement; DiveSensorBridge has TODO placeholder
9. **Compass** — UI stub only ("---°"), no implementation
10. **Feedback submission backend** — FeedbackView submit is stubbed (TODO: wire to API)
11. **Remote version check endpoint** — minimum safe version check is stubbed

---

## Out of Scope (do not implement)

- Tank pressure / air integration (no transmitter hardware)
- CCR / rebreather modes
- Actual App Store submission / entitlement provisioning
- Compass heading (stub only)
