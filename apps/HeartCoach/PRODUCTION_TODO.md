# Thump Production TODO

## Pricing And Packaging

- [x] Reduce the public subscription surface to `Free + Coach`.
- [x] Set Coach pricing in code to `$2.99/month`.
- [x] Set Coach annual pricing in code to `$17.99/year` to land at about 50% off monthly billing.
- [ ] Mirror the same price points in App Store Connect product configuration.
- [ ] Remove or archive legacy `Pro` and `Family` products after legacy subscribers are migrated or retired.

## Monetization Enforcement

- [x] Stop auto-enrolling every new user into launch-year free access.
- [x] Preserve grandfathered launch access for users who already have it.
- [ ] Wire `SubscriptionTier` feature gates into the actual iOS views and flows.
- [ ] Decide exactly which free features remain available without Coach.
- [ ] Add paywall entry points at the feature boundaries, not only from Settings.

## Product Copy And Trust

- [x] Update Settings subscription copy so the app no longer says everything is free.
- [x] Update the paywall to sell one Coach plan instead of three tiers.
- [x] Update launch-access copy to make it clear that complimentary access is grandfathered.
- [ ] Rewrite onboarding trust copy so it does not over-promise on-device-only behavior.
- [ ] Align website marketing copy with the in-app promise and pricing.

## Legal And Compliance

- [x] Update markdown legal docs to stop promising a free first year to all new users.
- [x] Update in-app legal text to reflect the single Coach offering.
- [ ] Review website legal pages for any stale launch-offer or pricing language.
- [ ] Re-check App Store privacy nutrition labels against current Firebase, telemetry, and bug-report behavior.

## Technical Readiness

- [ ] Create and test a StoreKit configuration file for local subscription testing.
- [ ] Remove simulator-only Coach auto-grant before release builds are finalized.
- [ ] Add end-to-end tests that verify free users hit the intended paywall gates.
- [ ] Verify restore-purchase and cancellation UX on device and in TestFlight.

## Launch Readiness

- [ ] Update App Store screenshots and website pricing section to match `Free + Coach`.
- [ ] Add conversion analytics for paywall view, trial start, purchase, restore, and cancellation.
- [ ] Run TestFlight with real Apple Watch users before spending on acquisition.
