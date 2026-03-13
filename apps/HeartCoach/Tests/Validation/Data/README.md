# Validation Dataset Files

Place downloaded CSV files here. Tests skip gracefully if files are missing.

## Expected Files

| Filename | Source | Download |
|---|---|---|
| `swell_hrv.csv` | SWELL-HRV (Kaggle) | kaggle.com/datasets/qiriro/swell-heart-rate-variability-hrv |
| `fitbit_daily.csv` | Fitbit Tracker (Kaggle) | kaggle.com/datasets/arashnic/fitbit |
| `walch_sleep.csv` | Walch Apple Watch Sleep (Kaggle) | kaggle.com/datasets/msarmi9/walch-apple-watch-sleep-dataset |

## Notes
- NTNU BioAge validation uses hardcoded reference tables (no CSV needed)
- CSV files are gitignored to avoid redistributing third-party data
- See `../FREE_DATASETS.md` for full dataset descriptions and validation plans
- Extended validation is run through Xcode, not the default SwiftPM target:
  - `xcodebuild test -project apps/HeartCoach/Thump.xcodeproj -scheme Thump -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ThumpCoreTests/StressEngineTimeSeriesTests -only-testing:ThumpCoreTests/DatasetValidationTests`
