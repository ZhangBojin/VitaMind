import Foundation
import HealthKit
import Observation

/// Manages stress monitoring using a single persistent HKWorkoutSession.
/// Once started (in foreground), the session continues running in background,
/// computing stress scores from a rolling HR buffer.
@MainActor
@Observable
final class StressMonitor {
    // MARK: - Published state

    private(set) var isSampling = false
    private(set) var latestStressScore: Int?
    private(set) var latestRMSSD: Double?
    private(set) var stressLevel: StressLevel = .unknown
    private(set) var lastUpdated: Date?
    private(set) var error: String?

    /// Callback invoked each time a new stress score is computed.
    var onStressResult: ((StressResult) -> Void)?

    // MARK: - Stress Result

    struct StressResult {
        let score: Int
        let rmssd: Double
        let level: StressLevel
        let timestamp: Date
    }

    enum StressLevel: String, CaseIterable {
        case relaxed
        case normal
        case alert
        case tense
        case unknown
    }

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private var session: HKWorkoutSession?
    private var builder: HKWorkoutBuilder?
    private var sampleTimer: Timer?
    private var computeTimer: Timer?
    /// Rolling buffer of (BPM, timestamp) for the last 5 minutes.
    private var hrBuffer: [(bpm: Double, time: Date)] = []
    private let collectionInterval: TimeInterval = 3.0
    private let computeInterval: TimeInterval = 300 // 5 min
    private var firstResultSent = false

    // MARK: - Public API

    func start() {
        guard !isSampling else { return }

        isSampling = true
        print("[StressMonitor] starting, isSampling = true")

        Task {
            await computeFromHistory()
            await runPersistentSession()
        }
    }

    func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        computeTimer?.invalidate()
        computeTimer = nil
        session?.end()
        session = nil
        builder = nil
        hrBuffer.removeAll()
        isSampling = false
        firstResultSent = false
    }

    // MARK: - Historical Data (instant first result)

    /// Query the last 30 minutes of heart rate data and compute an immediate stress score.
    /// This gives the user a result instantly, before the workout session ramps up.
    private func computeFromHistory() async {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-1800) // last 30 min
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let samples: [HKSample]
        do {
            samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: heartRateType,
                    predicate: predicate,
                    anchor: nil,
                    limit: HKObjectQueryNoLimit
                ) { _, results, _, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results ?? [])
                    }
                }
                healthStore.execute(query)
            }
        } catch {
            return
        }

        let bpms = samples
            .compactMap { $0 as? HKQuantitySample }
            .sorted { $0.startDate < $1.startDate }
            .map { $0.quantity.doubleValue(for: HKUnit(from: "count/min")) }

        guard bpms.count >= 5 else { return }

        computeStress(from: bpms, timestamp: Date())
    }

    // MARK: - Persistent Session

    private func runPersistentSession() async {
        isSampling = true
        hrBuffer.removeAll()
        if latestStressScore == nil {
            firstResultSent = false
        }
        error = nil

        // Try to start a workout session for high-frequency HR data.
        // On real Apple Watch this succeeds and provides ~1 Hz samples.
        // On simulator / unsupported devices it will fail, so we fall back
        // to regular HealthKit queries (lower frequency but still works).
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { [weak self] _, error in
                if let error {
                    Task { @MainActor in
                        print("[StressMonitor] beginCollection error: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("[StressMonitor] HKWorkoutSession unavailable, using observer fallback: \(error.localizedDescription)")
            session = nil
            builder = nil
            // Don't set isSampling = false — we continue with the fallback.
        }

        // Collect HR every few seconds (works with or without workout session).
        sampleTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.collectLatestHR()
                self?.tryFireFirstResult()
            }
        }

        // Regular computation every 5 minutes
        computeTimer = Timer.scheduledTimer(withTimeInterval: computeInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.computeFromRollingWindow()
            }
        }
    }

    // MARK: - Data Collection

    private func collectLatestHR() async {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-6),
            end: Date(),
            options: .strictStartDate
        )

        let samples: [HKSample]
        do {
            samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: heartRateType,
                    predicate: predicate,
                    anchor: nil,
                    limit: 1
                ) { _, results, _, _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: results ?? [])
                    }
                }
                healthStore.execute(query)
            }
        } catch {
            return
        }

        guard let latest = samples
            .compactMap({ $0 as? HKQuantitySample })
            .sorted(by: { $0.startDate > $1.startDate })
            .first
        else { return }

        let bpm = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
        hrBuffer.append((bpm: bpm, time: latest.startDate))

        // Keep only last 5 minutes
        let cutoff = Date().addingTimeInterval(-computeInterval)
        hrBuffer = hrBuffer.filter { $0.time >= cutoff }
    }

    // MARK: - Computation

    /// Fire the first result as soon as we have enough data (10+ samples),
    /// without waiting for the full 5-minute compute interval.
    private func tryFireFirstResult() {
        guard !firstResultSent, hrBuffer.count >= 10 else { return }
        firstResultSent = true
        let bpms = hrBuffer.map(\.bpm)
        computeStress(from: bpms, timestamp: Date())
    }

    private func computeFromRollingWindow() {
        guard hrBuffer.count >= 5 else { return }
        let bpms = hrBuffer.map(\.bpm)
        computeStress(from: bpms, timestamp: Date())
    }

    // MARK: - RMSSD & Stress

    private func computeStress(from bpmValues: [Double], timestamp: Date) {
        guard bpmValues.count >= 5 else { return }

        let rrIntervals = bpmValues.map { 60000.0 / $0 }

        var sumSquaredDiffs: Double = 0
        var count = 0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSquaredDiffs += diff * diff
            count += 1
        }
        guard count > 0 else { return }

        let rmssd = sqrt(sumSquaredDiffs / Double(count))
        let clampedRMSSD = max(5, min(200, rmssd))
        let logScale = log10(clampedRMSSD / 5.0) / log10(200.0 / 5.0)
        let score = Int(round((1.0 - logScale) * 100))

        let level: StressLevel
        switch score {
        case 0...25:  level = .relaxed
        case 26...50: level = .normal
        case 51...75: level = .alert
        default:      level = .tense
        }

        latestStressScore = score
        latestRMSSD = rmssd
        stressLevel = level
        lastUpdated = timestamp
        error = nil

        onStressResult?(StressResult(
            score: score,
            rmssd: rmssd,
            level: level,
            timestamp: timestamp
        ))
    }
}
