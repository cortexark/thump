# Contributing to Thump

## Development Setup

### Prerequisites
- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Apple Developer account with HealthKit entitlements
- iPhone running iOS 17+ and/or Apple Watch running watchOS 10+

### Getting Started

```bash
# Clone the repository
git clone <repo-url>
cd Apple-watch

# Generate the Xcode project
cd apps/HeartCoach
xcodegen generate
open Thump.xcodeproj
```

### Project Structure

| Directory | Purpose |
|-----------|---------|
| `apps/HeartCoach/iOS/` | iPhone app (Views, ViewModels, Services) |
| `apps/HeartCoach/Watch/` | Apple Watch app |
| `apps/HeartCoach/Shared/` | Code shared between iOS and watchOS targets |
| `apps/HeartCoach/Tests/` | Unit tests |
| `apps/HeartCoach/web/` | Landing page and legal documents |
| `scripts/` | Research and data pipeline scripts |
| `data/` | Market research data |

## Code Standards

### Swift Concurrency
- All `ObservableObject` classes must be `@MainActor`
- `WCSessionDelegate` methods must be `nonisolated` with `Task { @MainActor in }` hops
- Use `Task { @MainActor [weak self] in }` for cross-isolation property mutations
- Never use `DispatchQueue.main.async` for `@Published` property updates in `@MainActor` classes

### HealthKit
- All `HKQuantityType` / `HKCategoryType` constructors must use `guard let` (never force-unwrap)
- Apple hides read authorization status — do not check `authorizationStatus` for read permissions
- Validate `days > 0` before constructing date ranges

### Security
- Health data must be encrypted before persisting (use `CryptoService`)
- Keychain operations must be serialized (see `CryptoService.keyLock`)
- Never overwrite existing Keychain entries on `errSecDuplicateItem` — re-read first
- Never store health data in URL parameters or analytics events

### Medical Language
- Use suggestive language ("consider", "try", "you might") not prescriptive ("you should", "you must")
- Never claim to diagnose, treat, or prevent any condition
- Maintain FDA general wellness exemption positioning
- Include health disclaimer in onboarding flow

## Testing

```bash
# Run unit tests
xcodebuild test -scheme Thump -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Branching

- `main` — production-ready code
- `feature/*` — new features
- `fix/*` — bug fixes
- `release/*` — release preparation

## Commit Messages

Write concise commit messages that describe **what** changed and **why**:

```
Fix PaywallView infinite alert loop from .constant() binding

.constant() creates a read-only binding that ignores dismissal writes,
causing the alert to reappear immediately. Replace with custom Binding
that clears purchaseError on dismiss.
```
