import Foundation
import HealthKit
import Observation

/// Manages periodic 5-minute stress sampling sessions using HKWorkoutSession.
/// Collects high-frequency heart rate data during each session, computes RMSSD,
/// converts to a 0–100 stress score, and delivers the result.
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

    /// Callback invoked with the stress result after each 5-min session.
    var onStressResult: ((StressResult) -> Void)?

    // MARK: - Stress Result

    struct StressResult {
        let score: Int
        let rmssd: Double
        let level: StressLevel
        let timestamp: Date
    }

    enum StressLevel: String, CaseIterable {
        case relaxed  // 放松
        case normal   // 正常
        case alert    // 注意
        case tense    // 紧张
        case unknown  // 暂无数据
    }

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private var session: HKWorkoutSession?
    private var builder: HKWorkoutBuilder?
    private var sampleTimer: Timer?
    private var collectedHR: [Double] = []  // BPM values collected during session
    private let collectionInterval: TimeInterval = 3.0  // seconds between samples
    private let sessionDuration: TimeInterval = 300     // 5 minutes
    private let restartDelay: TimeInterval = 60         // 1 minute between sessions

    // MARK: - Public API

    /// Start the periodic stress monitoring cycle.
    /// First runs a quick 30-second sample for an immediate score,
    /// then proceeds with the full 5-min workout sessions.
    func start() {
        guard isAuthorized else {
            error = "HealthKit 未授权，无法启动压力监测。"
            return
        }
        Task {
            await runQuickSample()
            await runSession()
        }
    }

    /// Stop monitoring and end the current session if active.
    func stop() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        session?.end()
        session = nil
        isSampling = false
    }

    var isAuthorized: Bool {
        healthStore.authorizationStatus(for: heartRateType) == .sharingAuthorized
    }

    // MARK: - Quick Sample (30s, no workout needed)

    /// Collect ~10 HR samples over 30 seconds without starting a workout session.
    /// Delivers an immediate preliminary stress score so the UI isn't blank on launch.
    private func runQuickSample() async {
        isSampling = true
        collectedHR.removeAll()
        error = nil

        // Collect for 30 seconds, 1 sample every 3 seconds = ~10 samples
        let quickDuration: TimeInterval = 30
        let interval: TimeInterval = 3.0
        let start = Date()

        while Date().timeIntervalSince(start) < quickDuration {
            await collectLatestHR()
            try? await Task.sleep(for: .seconds(interval))
        }

        isSampling = false

        // Compute and deliver if we have enough data
        if collectedHR.count >= 5 {
            computeStress(from: collectedHR, timestamp: Date())
        }
    }

    // MARK: - Session Lifecycle

    private func runSession() async {
        guard !isSampling else { return }

        isSampling = true
        error = nil
        collectedHR.removeAll()

        // Configure workout
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
        } catch {
            self.error = "创建训练会话失败: \(error.localizedDescription)"
            isSampling = false
            scheduleNext()
            return
        }

        // Start session
        let startDate = Date()
        session?.startActivity(with: startDate)
        builder?.beginCollection(withStart: startDate) { [weak self] success, error in
            if let error {
                Task { @MainActor in
                    self?.error = "开始采集失败: \(error.localizedDescription)"
                }
            }
        }

        // Collect HR samples every few seconds
        sampleTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.collectLatestHR()
            }
        }

        // End session after the configured duration
        try? await Task.sleep(for: .seconds(sessionDuration))
        await finishSession(startDate: startDate)
    }

    private func finishSession(startDate: Date) async {
        sampleTimer?.invalidate()
        sampleTimer = nil

        session?.end()
        builder?.endCollection(withEnd: Date()) { [weak self] success, error in
            if let error {
                Task { @MainActor in
                    self?.error = "结束采集失败: \(error.localizedDescription)"
                }
            }
        }

        // Compute RMSSD and stress score from collected data
        computeStress(from: collectedHR, timestamp: Date())
        isSampling = false
        session = nil
        builder = nil

        scheduleNext()
    }

    // MARK: - Data Collection

    private func collectLatestHR() async {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-6), // last 6 seconds
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
        collectedHR.append(bpm)
    }

    // MARK: - RMSSD & Stress Computation

    private func computeStress(from bpmValues: [Double], timestamp: Date) {
        guard bpmValues.count >= 5 else {
            error = "心率样本不足，需要至少 5 个采样点。"
            return
        }

        // Convert BPM to RR intervals (ms)
        let rrIntervals = bpmValues.map { 60000.0 / $0 }

        // Compute RMSSD: sqrt(mean(diff²))
        var sumSquaredDiffs: Double = 0
        var count = 0
        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSquaredDiffs += diff * diff
            count += 1
        }
        guard count > 0 else {
            error = "无法计算 RMSSD：差值数量不足。"
            return
        }

        let rmssd = sqrt(sumSquaredDiffs / Double(count))

        // Map RMSSD to 0–100 stress score using logarithmic scale
        // High RMSSD → low stress, Low RMSSD → high stress
        let clampedRMSSD = max(5, min(200, rmssd))
        let logScale = log10(clampedRMSSD / 5.0) / log10(200.0 / 5.0) // 0 to 1
        let score = Int(round((1.0 - logScale) * 100)) // Invert: high RMSSD = low stress

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

    // MARK: - Scheduling

    private func scheduleNext() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.restartDelay ?? 60))
            await self?.runSession()
        }
    }
}
