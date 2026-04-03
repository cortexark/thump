# Heart Coach App Scaffold

This folder contains a cross-target scaffold for iPhone and Apple Watch:
- `Shared/`: common domain models and trend engine.
- `iOS/`: SwiftUI dashboard and iPhone services.
- `Watch/`: SwiftUI watch quick actions and feedback capture.

## Implementation Notes
- This is source-first scaffolding aligned to the orchestration artifacts.
- Shared logic is testable via Swift Package tests (`Package.swift`).
- For production, add Xcode targets and wire HealthKit/WatchConnectivity entitlements.
- `project.yml` is included for `xcodegen`-based project generation.

## Run Tests

### Core unit tests (no Xcode required)
```bash
cd apps/HeartCoach
swift test
```

### Engine time-series validation (280 checkpoints)
```bash
swift test --filter ThumpTimeSeriesTests
```

### Full integration tests (requires Xcode + Simulator)
```bash
xcodebuild test -project Thump.xcodeproj -scheme Thump \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

### UI tests with granular gate control
```bash
# Full bypass (legacy)
xcodebuild test ... -- -UITestMode

# Granular: test onboarding flow only
xcodebuild test ... -- -UITest_SignedIn -UITest_LegalAccepted

# Granular: test legal gate only
xcodebuild test ... -- -UITest_SignedIn
```
