// MetricKitService.swift
// Thump iOS
//
// Crash reporting and performance monitoring via Apple's MetricKit.
// Receives daily metric payloads and diagnostic reports (crashes,
// hangs, disk writes) and routes them through AppLogger for
// structured logging. No external dependencies required.
// Platforms: iOS 17+

import MetricKit
import os

// MARK: - MetricKit Service

/// Subscribes to MetricKit to capture system-level diagnostics and
/// performance metrics delivered by the OS (typically once per day).
///
/// Usage — call once at app launch:
/// ```swift
/// MetricKitService.shared.start()
/// ```
///
/// The service automatically receives:
/// - **Metric payloads**: CPU time, memory, launch duration, etc.
/// - **Diagnostic payloads**: Crash logs, hang reports, disk-write exceptions.
final class MetricKitService: NSObject, MXMetricManagerSubscriber {

    // MARK: - Singleton

    static let shared = MetricKitService()

    // MARK: - Initialization

    override private init() { super.init() }

    // MARK: - Public API

    /// Whether `start()` has already been called.
    private var isStarted = false

    /// Registers the service as a MetricKit subscriber.
    /// Call this once during app launch (e.g. in `performStartupTasks`).
    /// Guarded against repeated registration (PERF-5).
    func start() {
        guard !isStarted else { return }
        isStarted = true
        MXMetricManager.shared.add(self)
        AppLogger.info("MetricKit subscriber registered")
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called by the system when daily metric payloads are available.
    ///
    /// - Parameter payloads: One or more metric snapshots covering
    ///   roughly the previous 24 hours.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            AppLogger.info("Received metric payload through: \(payload.timeStampEnd)")

            if let cpuMetrics = payload.cpuMetrics {
                AppLogger.debug("CPU time: \(cpuMetrics.cumulativeCPUTime.formatted())")
            }
            if let memoryMetrics = payload.memoryMetrics {
                AppLogger.debug("Peak memory: \(memoryMetrics.peakMemoryUsage.formatted())")
            }
            if let launchMetrics = payload.applicationLaunchMetrics {
                if let resumeTime = launchMetrics.histogrammedTimeToFirstDraw
                    .bucketEnumerator.allObjects.last as? MXHistogramBucket<UnitDuration> {
                    AppLogger.debug("Launch time bucket ceiling: \(resumeTime.bucketEnd.formatted())")
                }
            }
        }
    }

    /// Called by the system when diagnostic payloads (crashes, hangs,
    /// disk-write exceptions) are available.
    ///
    /// - Parameter payloads: One or more diagnostic snapshots.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Dump interaction breadcrumbs so crash context is visible in logs
        CrashBreadcrumbs.shared.dump()

        for payload in payloads {
            AppLogger.error("Received diagnostic payload (potential crash)")

            if let crashDiagnostics = payload.crashDiagnostics {
                for crash in crashDiagnostics {
                    AppLogger.error(
                        "Crash: \(crash.applicationVersion) - \(crash.terminationReason ?? "unknown")"
                    )
                }
            }
            if let hangDiagnostics = payload.hangDiagnostics {
                for hang in hangDiagnostics {
                    AppLogger.warning("Hang detected: \(hang.hangDuration.formatted())")
                }
            }
            if let diskWriteDiagnostics = payload.diskWriteExceptionDiagnostics {
                for diskWrite in diskWriteDiagnostics {
                    AppLogger.warning(
                        "Disk write exception: \(diskWrite.applicationVersion)"
                    )
                }
            }
        }
    }
}
