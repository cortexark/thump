# Privacy Policy

**Last Updated: March 14, 2026**

Thump ("we," "our," or "the app") is a heart health and wellness application for iPhone and Apple Watch. This Privacy Policy explains how we collect, use, store, and protect your information when you use Thump.

By using Thump, you consent to the data practices described in this policy.

---

## 1. Information We Collect

### 1.1 Health and Fitness Data (Apple HealthKit)

With your explicit permission, Thump reads the following data from Apple Health:

- Resting heart rate
- Heart rate variability (HRV)
- Heart rate recovery
- VO2 max
- Step count
- Walking and running distance
- Active energy burned
- Exercise minutes
- Sleep analysis
- Body weight
- Height
- Biological sex
- Date of birth

**Important:** We only read this data to generate wellness insights. We never sell, share, or use your raw health data for advertising, marketing, or data mining purposes.

### 1.2 Account Information

When you sign in with Apple, we receive an anonymous, app-specific identifier issued by Apple. We do not receive or store your name, email address, or other personal information from your Apple ID.

### 1.3 Subscription Information

Thump is free for the first year with full access to all features. No payment information is collected during this period. If you choose to subscribe after the free period, Apple processes your payment. We only receive confirmation of your subscription tier and its status. We do not have access to your payment method, credit card number, or billing address.

### 1.4 Usage Analytics (Opt-In)

If you enable "Share Engine Insights" in Settings, we collect anonymized performance data about how our wellness engines compute your scores. This includes:

- Computed wellness scores (e.g., readiness score, stress level, bio age)
- Engine confidence levels and timing data
- App version, build number, and device model

**This data never includes your raw health values** (heart rate, HRV, steps, sleep hours, etc.). Only the computed scores and engine performance metrics are collected.

You can disable this at any time in Settings > Analytics.

In debug/development builds, this data collection is enabled by default for quality assurance purposes.

### 1.5 Device Information

We may collect basic device information such as device model (e.g., "iPhone 16") for engine performance analysis. We do not collect device identifiers (UDID, IDFA) or location data.

---

## 2. How We Use Your Information

We use the information we collect to:

- **Provide wellness insights:** Analyze your health data to generate heart trend assessments, readiness scores, stress levels, bio age estimates, coaching recommendations, and daily nudges.
- **Sync between devices:** Transfer wellness insights (not raw health data) between your iPhone and Apple Watch via WatchConnectivity.
- **Send local notifications:** Deliver anomaly alerts and wellness nudges directly on your device. Notification content never includes specific health metric values.
- **Improve our engines:** If you opt in, anonymized engine performance data helps us improve the accuracy of our wellness algorithms.
- **Manage subscriptions:** Determine which features are available based on your subscription tier.

---

## 3. How We Store Your Information

### 3.1 On-Device Storage

Your health data is stored locally on your device using AES-256-GCM encryption. Data is stored in the app's sandboxed container and protected by your device's passcode and biometric authentication.

- Health snapshot history: up to 365 days stored locally
- User profile and preferences: stored in encrypted local storage
- Apple Sign-In identifier: stored in the iOS Keychain

### 3.2 Cloud Storage

If you opt in to "Share Engine Insights," anonymized engine performance data is stored in Google Firebase Firestore. This data is:

- Linked to a pseudonymous identifier (a one-way SHA-256 hash of your Apple Sign-In ID)
- Stored on Google Cloud infrastructure with encryption at rest and in transit
- Not linked to your real identity, email, or personal information
- Retained for engine quality analysis purposes

**We do not store raw health data in the cloud.** Your heart rate, HRV, sleep, steps, and other HealthKit values never leave your device.

### 3.3 iCloud

We do not store any health or personal data in iCloud.

---

## 4. How We Share Your Information

**We do not sell your data.** We do not share your information with third parties for advertising, marketing, or data mining purposes.

We may share limited information with the following service providers:

| Service | Data Shared | Purpose |
|---------|------------|---------|
| Apple (HealthKit) | Health data remains on device | Reading health metrics |
| Apple (Sign in with Apple) | Anonymous user identifier | Authentication |
| Apple (StoreKit) | Subscription status | Payment processing |
| Google Firebase Firestore | Anonymized engine scores, device model, app version | Engine quality analysis (opt-in only) |

No other third parties receive any data from Thump.

---

## 5. Push Notifications

Thump uses **local notifications only** (not remote/cloud push notifications). Notifications are generated entirely on your device based on your health assessments.

- **Anomaly alerts:** Notify you when your health metrics deviate from your personal baseline.
- **Wellness nudges:** Remind you about daily wellness activities (walking, hydration, breathing exercises, etc.).

Notification content never includes specific health metric values (e.g., your actual heart rate number). You can disable notifications at any time in your device's Settings.

---

## 6. Data Retention

- **On-device data:** Retained as long as you use the app. Deleted when you uninstall Thump.
- **Firebase data (opt-in):** Anonymized engine performance data is retained for quality analysis. Since this data is pseudonymous and contains no raw health values, it cannot be linked back to you after account deletion.
- **Apple Sign-In:** Your credential is stored in the Keychain and deleted if you revoke access through Apple ID settings.

---

## 7. Your Rights and Choices

You have control over your data:

- **HealthKit permissions:** You can grant or revoke access to specific health data types at any time in Settings > Health > Thump.
- **Engine insights:** You can opt in or out of anonymized engine data collection in Thump Settings > Analytics.
- **Notifications:** You can enable or disable notifications in your device's Settings.
- **Delete your data:** Uninstalling Thump removes all locally stored data. To request deletion of any cloud-stored anonymized data, contact us at the email below.
- **Sign-In revocation:** You can revoke Sign in with Apple access at any time through Settings > Apple ID > Password & Security > Apps Using Your Apple ID.

---

## 8. Children's Privacy

Thump is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with personal information, please contact us so we can delete it.

---

## 9. Security

We implement industry-standard security measures to protect your data:

- AES-256-GCM encryption for locally stored health data
- iOS Keychain for sensitive credentials
- SHA-256 hashing for pseudonymous identifiers
- HTTPS/TLS for all network communications
- Firebase security rules for cloud-stored data

No method of transmission or storage is 100% secure. While we strive to protect your information, we cannot guarantee absolute security.

---

## 10. International Users

Thump processes data on your device and, if opted in, on Google Cloud servers. By using Thump, you consent to the transfer and processing of your anonymized data in the regions where Google Cloud operates.

---

## 11. Changes to This Policy

We may update this Privacy Policy from time to time. We will notify you of any material changes by updating the "Last Updated" date at the top of this policy. Your continued use of Thump after changes are posted constitutes your acceptance of the updated policy.

---

## 12. Contact Us

If you have questions about this Privacy Policy or your data, please contact us at:

**Email:** privacy@thump.app

---

*This privacy policy complies with Apple's App Store Review Guidelines (Section 5.1), HealthKit usage requirements, the EU General Data Protection Regulation (GDPR), and the California Consumer Privacy Act (CCPA).*
