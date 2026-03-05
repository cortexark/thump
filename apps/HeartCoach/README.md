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

## Run Core Tests
```bash
cd /Users/t/workspace/Apple-watch/apps/Thump
swift test
```

## Generate Xcode Project (optional)
```bash
cd /Users/t/workspace/Apple-watch/apps/Thump
xcodegen generate
```
