# Validation Dataset Files

Place downloaded CSV files here. Tests skip gracefully if files are missing.

## Expected Files

| Filename | Source | Download |
|---|---|---|
| `swell_hrv.csv` | SWELL-HRV (Kaggle) | kaggle.com/datasets/qiriro/swell-heart-rate-variability-hrv |
| `WESAD.zip` | WESAD official archive | ubi29.informatik.uni-siegen.de/usi/data_wesad.html |
| `wesad_e4_mirror/` | Local derived WESAD wrist-data mirror | generated locally from `WESAD.zip` |
| `physionet_exam_stress/` | PhysioNet Wearable Exam Stress | physionet.org/content/wearable-exam-stress/ |
| `fitbit_daily.csv` | Fitbit Tracker (Kaggle) | kaggle.com/datasets/arashnic/fitbit |
| `walch_sleep.csv` | Walch Apple Watch Sleep (Kaggle) | kaggle.com/datasets/msarmi9/walch-apple-watch-sleep-dataset |

## Notes
- NTNU BioAge validation uses hardcoded reference tables (no CSV needed)
- CSV files are gitignored to avoid redistributing third-party data
- `physionet_exam_stress/` is a lightweight local mirror:
  - `S1...S10/<exam>/HR.csv`
  - `S1...S10/<exam>/IBI.csv`
  - `S1...S10/<exam>/info.txt`
  - only the files needed for StressEngine validation are mirrored locally
- `wesad_e4_mirror/` is a lightweight local mirror generated from `WESAD.zip`:
  - `S2...S17/HR.csv`
  - `S2...S17/IBI.csv`
  - `S2...S17/info.txt`
  - `S2...S17/quest.csv`
  - only the files needed for StressEngine wrist validation are mirrored locally
- See `../FREE_DATASETS.md` for full dataset descriptions and validation plans
- Extended validation is run through Xcode, not the default SwiftPM target:
  - `xcodebuild test -project apps/HeartCoach/Thump.xcodeproj -scheme Thump -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ThumpCoreTests/StressEngineTimeSeriesTests -only-testing:ThumpCoreTests/DatasetValidationTests`
