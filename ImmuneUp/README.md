
# ImmuneUp (SwiftUI · HealthKit · SwiftData · Combine · iOS 17+)

This zip contains a **ready-to-run SwiftUI iOS app source tree** with:
- HealthKit integration (steps + active energy / kcal)
- SwiftData persistence (1 record per day · `DailySummary` model)
- Combine
- A simple, updatable **linear regression** (1-layer) model that predicts **ImmuneScore (1–100)** from 5 inputs
- 4 tabs: **Home · Statistiken · Coach · Profil**
- Example data for the last 10 days seeded at first launch

> Note: Creating a full `.xcodeproj` in this environment is brittle. Follow the 1‑minute steps below to generate the project in Xcode and run on device/simulator.

## Quick Start (Xcode 15/16/17 · iOS 17+)

1. Open Xcode → **File > New > Project…** → iOS **App**.  
   - **Product Name**: `ImmuneUp`  
   - **Interface**: SwiftUI · **Language**: Swift · **Use Core Data**: off · **Include Tests**: off
2. Quit Xcode. In Finder, replace the contents of the generated `ImmuneUp` folder with the files from this zip’s `ImmuneUp` folder.
3. Reopen the project in Xcode:
   - Select the app **target** → **Signing & Capabilities** → **+ Capability** → add **HealthKit** and **Background Modes (optional)**.
   - In **Info**, ensure these keys exist (already provided in `Info.plist`):  
     - **Privacy – Health Share Usage Description**  
     - **Privacy – Health Update Usage Description**
4. Build & run on an iOS 17+ simulator or device. The app handles missing HealthKit permissions gracefully.
   - On first launch, it seeds 10 days of example data.
   - In **Profil**, set your goals & allow notifications (optional).

## What’s inside

- `ImmuneUpApp.swift`: App entry with SwiftData container.
- `Models/DailySummary.swift`: SwiftData model (`@Model`) with unique day key.
- `Services/HealthKitManager.swift`: Authorization + today’s steps & kcal fetch.
- `Services/MLLinearModel.swift`: Simple linear regression (equal-weight baseline; updatable).
- `ViewModels/AppState.swift`: Orchestration, seeding sample data, syncing HealthKit into today.
- `Views/…`: `HomeView`, `StatsView`, `CoachView`, `ProfileView`.
- `Components/…`: Score card, trend chart, and the four tiles.
- `Persistence/ModelContainer.swift`: Shared SwiftData container builder.
- `Assets.xcassets/AppIcon.appiconset`: Placeholder app icon.
- `ImmuneUp.entitlements`: HealthKit entitlements template (Xcode will regenerate as needed).
- `Info.plist`: Required privacy strings for HealthKit.

## HealthKit types
- **Steps** (`HKQuantityTypeIdentifier.stepCount`) — sum for today
- **Active Energy** (`HKQuantityTypeIdentifier.activeEnergyBurned`) — kcal sum for today

## ML model
- Inputs (normalized to 0…1):  
  sleepDuration, steps, kcal, stress (inverted), screenTime (inverted)  
  **Baseline** score = `20 * sum(inputs)` (equal weights).  
  Model parameters (weights + bias) are stored in `UserDefaults` and can be updated on-device via simple gradient descent against your data.

---

© 2025-10-12 – Example code for education purposes.
