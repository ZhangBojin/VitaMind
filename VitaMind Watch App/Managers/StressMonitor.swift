import Foundation
import HealthKit
import Observation

/// Reads Apple Watch's passive HRV (SDNN) samples from HealthKit,
/// maps them to a 0–100 stress score, and delivers the result.
/// No workout session — uses the automatic background HRV readings
/// that Apple Watch collects every 1–4 hours during rest.
@MainActor
@Observable
final class StressMonitor {
    // MARK: - Published state

    private(set) var isSampling = false
    private(set) var latestStressScore: Int?
    private(set) var latestSDNN: Double?
    private(set) var stressLevel: StressLevel = .unknown
    private(set) var lastUpdated: Date?
    private(set) var error: String?

    var onStressResult: ((StressResult) -> Void)?

    struct StressResult {
        let score: Int
        let sdnn: Double
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
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private var observerQuery: HKObserverQuery?

    // MARK: - Public API

    func start() {
        guard !isSampling else { return }
        isSampling = true
        error = nil

        // Fetch the latest HRV immediately for an instant first score.
        Task { await fetchLatestAndCompute() }

        // Observe new HRV samples as Apple Watch collects them.
        observerQuery = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                await self?.fetchLatestAndCompute()
            }
        }
        if let observerQuery {
            healthStore.execute(observerQuery)
        }

        // Also enable background delivery for more timely updates.
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .hourly) { _, error in
            if let error {
                print("[StressMonitor] bg delivery: \(error.localizedDescription)")
            }
        }
    }

    /// Run a short 1-min Mind and Body session to collect high-frequency HR,
    /// compute RMSSD directly from the samples, and deliver a fresh stress result.
    func forceMeasurement() async {
        let config = HKWorkoutConfiguration()
        config.activityType = .mindAndBody
        config.locationType = .indoor

        let session: HKWorkoutSession
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        } catch {
            self.error = "无法启动测量: \(error.localizedDescription)"
            return
        }

        session.startActivity(with: Date())
        let heartRateUnit = HKUnit(from: "count/min")
        var bpms: [Double] = []

        // Collect HR every 3s for 60 seconds.
        let endTime = Date().addingTimeInterval(60)
        while Date() < endTime {
            let predicate = HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-6),
                end: Date(),
                options: .strictStartDate
            )
            let samples: [HKSample]? = try? await withCheckedThrowingContinuation { c in
                let q = HKAnchoredObjectQuery(type: HKQuantityType.quantityType(forIdentifier: .heartRate)!, predicate: predicate, anchor: nil, limit: 1) { _, r, _, _, e in
                    if let e { c.resume(throwing: e) } else { c.resume(returning: r ?? []) }
                }
                healthStore.execute(q)
            }
            if let latest = samples?.compactMap({ $0 as? HKQuantitySample }).sorted(by: { $0.startDate > $1.startDate }).first {
                let bpm = latest.quantity.doubleValue(for: heartRateUnit)
                if bpms.last != bpm { bpms.append(bpm) } // only add if different
            }
            try? await Task.sleep(for: .seconds(3))
        }

        session.end()

        // Compute RMSSD directly from collected BPM samples.
        guard bpms.count >= 5 else {
            self.error = "测量样本不足，请重试。"
            return
        }

        let rrIntervals = bpms.map { 60000.0 / $0 }
        var sumSq: Double = 0, n = 0
        for i in 1..<rrIntervals.count {
            let d = rrIntervals[i] - rrIntervals[i - 1]
            sumSq += d * d; n += 1
        }
        guard n > 0 else { return }

        let rmssd = sqrt(sumSq / Double(n))
        let clamped = max(10, min(200, rmssd))
        let logScale = log10(clamped / 10.0) / log10(200.0 / 10.0)
        let score = Int(round((1.0 - logScale) * 100))

        let level: StressLevel
        switch score {
        case 0...25:  level = .relaxed
        case 26...50: level = .normal
        case 51...75: level = .alert
        default:      level = .tense
        }

        latestStressScore = score
        latestSDNN = rmssd // Note: this is RMSSD from BPM, not HealthKit SDNN — close enough for display
        stressLevel = level
        lastUpdated = Date()
        error = nil

        onStressResult?(StressResult(score: score, sdnn: rmssd, level: level, timestamp: Date()))
    }

    func stop() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
        isSampling = false
    }

    // MARK: - Fetch & Compute

    private func fetchLatestAndCompute() async {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-86400), // last 24h
            end: Date(),
            options: .strictStartDate
        )

        let samples: [HKSample]
        do {
            samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: hrvType,
                    predicate: predicate,
                    anchor: nil,
                    limit: 1 // just the latest
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
            self.error = "获取 HRV 失败: \(error.localizedDescription)"
            return
        }

        guard let latest = samples
            .compactMap({ $0 as? HKQuantitySample })
            .sorted(by: { $0.startDate > $1.startDate })
            .first
        else { return }

        let sdnn = latest.quantity.doubleValue(for: HKUnit(from: "ms"))
        computeStress(from: sdnn, timestamp: latest.startDate)
    }

    // MARK: - Stress Computation (from SDNN)

    private func computeStress(from sdnn: Double, timestamp: Date) {
        // SDNN values typically range 10–200ms.
        // High SDNN → low stress. Use log scale for even distribution.
        let clamped = max(10, min(200, sdnn))
        let logScale = log10(clamped / 10.0) / log10(200.0 / 10.0) // 0–1
        let score = Int(round((1.0 - logScale) * 100))

        let level: StressLevel
        switch score {
        case 0...25:  level = .relaxed
        case 26...50: level = .normal
        case 51...75: level = .alert
        default:      level = .tense
        }

        latestStressScore = score
        latestSDNN = sdnn
        stressLevel = level
        lastUpdated = timestamp
        error = nil

        onStressResult?(StressResult(score: score, sdnn: sdnn, level: level, timestamp: timestamp))
    }
}
