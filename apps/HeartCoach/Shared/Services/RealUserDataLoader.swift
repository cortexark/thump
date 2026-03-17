// RealUserDataLoader.swift
// ThumpCore
//
// Debug utility: loads real Apple Watch data exported via
// convert_health_export.py into HeartSnapshot arrays for simulator testing.
//
// This replays YOUR actual daily metrics — including nil fields, gaps,
// and partial days — so the engines behave exactly as they would on device.
//
// The JSON file (RealUserSnapshots.json) is gitignored and never shipped.
//
// Usage:
//   let loader = RealUserDataLoader()
//   let snapshots = loader.loadSnapshots()        // all days, original dates
//   let anchored  = loader.loadAnchored(days: 30) // last 30 days re-dated to end today
//
// Platforms: iOS 17+, macOS 14+

import Foundation

// MARK: - Real User Data Loader

/// Loads real Apple Watch export data from a JSON file for simulator testing.
///
/// The JSON is produced by `convert_health_export.py` from an Apple Health
/// XLSX export. Each entry maps directly to a ``HeartSnapshot`` with nullable
/// fields preserved (no synthetic fill-in), so engines see the same data
/// quality as the real device.
public enum RealUserDataLoader {

    // MARK: - JSON Model

    /// Intermediate Codable model matching the Python converter output.
    /// Uses explicit optionals for every field since real exports have gaps.
    private struct RawSnapshot: Codable {
        let date: String
        let restingHeartRate: Double?
        let hrvSDNN: Double?
        let recoveryHR1m: Double?
        let recoveryHR2m: Double?
        let vo2Max: Double?
        let zoneMinutes: [Double]?
        let steps: Double?
        let walkMinutes: Double?
        let workoutMinutes: Double?
        let sleepHours: Double?
        let bodyMassKg: Double?
        let heightM: Double?
    }

    // MARK: - Date Parsing

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fallbackFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func parseDate(_ str: String) -> Date {
        if let d = isoFormatter.date(from: str) { return d }
        if let d = fallbackFormatter.date(from: str) { return d }
        // Last resort: try just the date portion
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.date(from: String(str.prefix(10))) ?? Date()
    }

    // MARK: - Loading

    /// Search paths for the JSON file (checked in order).
    private static var searchPaths: [URL] {
        var paths: [URL] = []

        // 1. Bundle resource (if added to test target)
        if let bundled = Bundle.main.url(forResource: "RealUserSnapshots", withExtension: "json") {
            paths.append(bundled)
        }

        // 2. Tests/Validation/Data/ relative to source root
        //    Works when running from Xcode with SRCROOT set
        if let srcRoot = ProcessInfo.processInfo.environment["SRCROOT"] {
            paths.append(URL(fileURLWithPath: srcRoot)
                .appendingPathComponent("Tests/Validation/Data/RealUserSnapshots.json"))
        }

        // 3. Common development paths
        let devPaths = [
            "apps/HeartCoach/Tests/Validation/Data/RealUserSnapshots.json",
            "Tests/Validation/Data/RealUserSnapshots.json",
        ]
        for rel in devPaths {
            // Walk up from current working directory
            var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            for _ in 0..<5 {
                let candidate = dir.appendingPathComponent(rel)
                paths.append(candidate)
                dir = dir.deletingLastPathComponent()
            }
        }

        return paths
    }

    /// Load all snapshots from the JSON file with original dates.
    /// Returns empty array if file not found (no crash in production).
    public static func loadSnapshots() -> [HeartSnapshot] {
        guard let url = searchPaths.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            print("[RealUserDataLoader] RealUserSnapshots.json not found in search paths")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([RawSnapshot].self, from: data)

            let snapshots = raw.map { r in
                HeartSnapshot(
                    date: Calendar.current.startOfDay(for: parseDate(r.date)),
                    restingHeartRate: r.restingHeartRate,
                    hrvSDNN: r.hrvSDNN,
                    recoveryHR1m: r.recoveryHR1m,
                    recoveryHR2m: r.recoveryHR2m,
                    vo2Max: r.vo2Max,
                    zoneMinutes: r.zoneMinutes ?? [],
                    steps: r.steps,
                    walkMinutes: r.walkMinutes,
                    workoutMinutes: r.workoutMinutes,
                    sleepHours: r.sleepHours,
                    bodyMassKg: r.bodyMassKg,
                    heightM: r.heightM
                )
            }

            print("[RealUserDataLoader] Loaded \(snapshots.count) snapshots from \(url.lastPathComponent)")
            return snapshots.sorted { $0.date < $1.date }
        } catch {
            print("[RealUserDataLoader] Failed to load: \(error)")
            return []
        }
    }

    /// Load the most recent N days, re-dated so the last day = today.
    /// This ensures date-sensitive engines (stress trends, readiness) work
    /// correctly in the simulator without needing real-time data.
    ///
    /// - Parameter days: Number of days to load (from the end of the dataset).
    /// - Returns: Array of snapshots with dates anchored to today, oldest first.
    public static func loadAnchored(days: Int = 30) -> [HeartSnapshot] {
        let all = loadSnapshots()
        guard !all.isEmpty else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let slice = Array(all.suffix(days))

        return slice.enumerated().map { idx, snapshot in
            let daysBack = slice.count - 1 - idx
            let anchoredDate = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today

            return HeartSnapshot(
                date: anchoredDate,
                restingHeartRate: snapshot.restingHeartRate,
                hrvSDNN: snapshot.hrvSDNN,
                recoveryHR1m: snapshot.recoveryHR1m,
                recoveryHR2m: snapshot.recoveryHR2m,
                vo2Max: snapshot.vo2Max,
                zoneMinutes: snapshot.zoneMinutes,
                steps: snapshot.steps,
                walkMinutes: snapshot.walkMinutes,
                workoutMinutes: snapshot.workoutMinutes,
                sleepHours: snapshot.sleepHours,
                bodyMassKg: snapshot.bodyMassKg,
                heightM: snapshot.heightM
            )
        }
    }

    /// Summary statistics for debugging.
    public static func printSummary() {
        let all = loadSnapshots()
        guard !all.isEmpty else {
            print("[RealUserDataLoader] No data loaded")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        let rhrCount = all.compactMap(\HeartSnapshot.restingHeartRate).count
        let hrvCount = all.compactMap(\HeartSnapshot.hrvSDNN).count
        let sleepCount = all.compactMap(\HeartSnapshot.sleepHours).count
        let stepsCount = all.compactMap(\HeartSnapshot.steps).count
        let vo2Count = all.compactMap(\HeartSnapshot.vo2Max).count

        print("""
        [RealUserDataLoader] Summary:
          Total days: \(all.count)
          Date range: \(dateFormatter.string(from: all.first!.date)) – \(dateFormatter.string(from: all.last!.date))
          RHR:   \(rhrCount)/\(all.count) days (\(100 * rhrCount / all.count)%)
          HRV:   \(hrvCount)/\(all.count) days (\(100 * hrvCount / all.count)%)
          Sleep: \(sleepCount)/\(all.count) days (\(100 * sleepCount / all.count)%)
          Steps: \(stepsCount)/\(all.count) days (\(100 * stepsCount / all.count)%)
          VO2:   \(vo2Count)/\(all.count) days (\(100 * vo2Count / all.count)%)
        """)
    }
}
