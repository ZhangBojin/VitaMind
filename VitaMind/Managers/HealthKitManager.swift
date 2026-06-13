import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class HealthKitManager {
    // MARK: - Published state

    private(set) var isAuthorized = false
    private(set) var latestHeartRate: Double?
    private(set) var heartRateSamples: [HeartRateSample] = []
    private(set) var error: String?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let cache = LocalCacheManager()
    private var observerQuery: HKObserverQuery?

    // MARK: - Init

    init() {
        // Restore previously cached samples so the UI shows data immediately.
        let cached = cache.load()
        if !cached.isEmpty {
            heartRateSamples = cached
            latestHeartRate = cached.first?.bpm
        }
    }

    // MARK: - Cache Integration

    /// Merge externally-provided samples (e.g., from Watch) into the local dataset.
    func ingestSamples(_ incoming: [HeartRateSample]) {
        let existingIDs = Set(heartRateSamples.map(\.id))
        let uniqueNew = incoming.filter { !existingIDs.contains($0.id) }
        guard !uniqueNew.isEmpty else { return }
        heartRateSamples = (uniqueNew + heartRateSamples).sorted { $0.date > $1.date }
        latestHeartRate = heartRateSamples.first?.bpm
        cache.save(heartRateSamples)
    }

    // MARK: - Authorization

    /// Request HealthKit authorization to read heart rate data.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "HealthKit is not available on this device."
            return
        }

        let readTypes: Set<HKObjectType> = [heartRateType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            error = nil
        } catch {
            self.error = "HealthKit authorization failed: \(error.localizedDescription)"
            isAuthorized = false
        }
    }

    // MARK: - Data Fetching

    /// Fetch heart rate samples for a date range.
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date = Date()) async {
        guard isAuthorized else {
            error = "HealthKit not authorized. Call requestAuthorization() first."
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
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

            let heartRateSamples = samples
                .compactMap { $0 as? HKQuantitySample }
                .map { sample in
                    HeartRateSample(
                        bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                        date: sample.startDate,
                        source: sample.sourceRevision.source.name
                    )
                }

            self.heartRateSamples = heartRateSamples
            self.latestHeartRate = heartRateSamples.first?.bpm
            self.error = nil
            cache.save(heartRateSamples)
        } catch {
            self.error = "Failed to fetch heart rate: \(error.localizedDescription)"
        }
    }

    /// Start observing for new heart rate samples. Delivers updates via `latestHeartRate`.
    func startHeartRateObserver() {
        guard isAuthorized else { return }

        // Enable background delivery on watchOS only
        #if os(watchOS)
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error {
                Task { @MainActor in
                    self.error = "Background delivery: \(error.localizedDescription)"
                }
            }
        }
        #endif

        // Observer query notifies us when new data is written by other apps/devices
        observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error {
                Task { @MainActor in
                    self?.error = "Observer error: \(error.localizedDescription)"
                }
                completionHandler()
                return
            }
            // Fetch the latest sample
            Task { @MainActor [weak self] in
                await self?.fetchLatestHeartRate()
            }
            completionHandler()
        }

        if let observerQuery {
            healthStore.execute(observerQuery)
        }
    }

    /// Stop heart rate observation.
    func stopHeartRateObserver() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
    }

    // MARK: - Private Helpers

    private func fetchLatestHeartRate() async {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600),
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
            self.error = "Failed to fetch latest: \(error.localizedDescription)"
            return
        }

        let newSamples = samples
            .compactMap { $0 as? HKQuantitySample }
            .map { sample in
                HeartRateSample(
                    bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
                    date: sample.startDate,
                    source: sample.sourceRevision.source.name
                )
            }

        // Merge new samples, avoiding duplicates
        let existingIDs = Set(heartRateSamples.map(\.id))
        let uniqueNew = newSamples.filter { !existingIDs.contains($0.id) }
        heartRateSamples = (uniqueNew + heartRateSamples).sorted { $0.date > $1.date }

        if let first = heartRateSamples.first {
            latestHeartRate = first.bpm
        }
        cache.save(heartRateSamples)
        error = nil
    }
}
