# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Data Protection

Thump takes health data security seriously:

- **On-device only**: Health data never leaves the user's device
- **Encrypted at rest**: All health snapshots are encrypted with AES-256-GCM before storage
- **Keychain-protected keys**: Encryption keys are stored in the iOS/watchOS Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
- **No server-side storage**: No backend servers store or process user health data
- **Anonymous analytics**: Usage analytics contain no personally identifiable information or health data
- **Scoped HealthKit access**: Read-only access to specific metrics; no write access requested

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue
2. Email: security@thump.app
3. Include steps to reproduce and potential impact
4. We will acknowledge receipt within 48 hours
5. We will provide a fix timeline within 7 days

## Threat Model

### In Scope
- Local data encryption and key management
- HealthKit permission handling
- WatchConnectivity message integrity
- StoreKit transaction validation
- UserDefaults data protection

### Out of Scope
- Physical device access (device passcode is the first line of defense)
- Jailbroken devices
- Apple framework vulnerabilities (report to Apple)
