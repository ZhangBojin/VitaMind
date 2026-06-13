import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class WatchHealthKitManager {
    // MARK: - Published state

    private(set) var isAuthorized = false
    private(set) var latestHeartRate: Double?
    private(set) var lastUpdated: Date?
    private(set) var error: String?

    /// Callback invoked each time a new heart rate sample arrives.
    /// The WatchConnectivity manager uses this to forward data to the phone.
    var onNewHeartRate: ((HeartRateSample) -> Void)?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private var observerQuery: HKObserverQuery?

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "HealthKit unavailable on this device."
            return
        }

        let readTypes: Set<HKObjectType> = [heartRateType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            error = nil
        } catch {
            self.error = "Authorization failed: \(error.localizedDescription)"
            isAuthorized = false
        }
    }

    // MARK: - Observation

    /// Begin observing heart rate. On watchOS, enables background delivery for frequent updates.
    func startObserving() {
        guard isAuthorized else { return }

        // Enable background delivery for more frequent updates on the watch
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { _, error in
            if let error {
                Task { @MainActor in
                    self.error = "Background delivery: \(error.localizedDescription)"
                }
            }
        }

        observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            if let error {
                Task { @MainActor in
                    self?.error = "Observer error: \(error.localizedDescription)"
                }
                return
            }
            Task { @MainActor [weak self] in
                await self?.fetchLatest()
            }
        }

        if let observerQuery {
            healthStore.execute(observerQuery)
        }

        // Also do an immediate fetch
        Task { await fetchLatest() }
    }

    func stopObserving() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
    }

    // MARK: - Private

    private func fetchLatest() async {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-600),
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
            self.error = "Fetch failed: \(error.localizedDescription)"
            return
        }

        guard let latestSample = samples
            .compactMap({ $0 as? HKQuantitySample })
            .sorted(by: { $0.startDate > $1.startDate })
            .first
        else { return }

        let bpm = latestSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        let sample = HeartRateSample(
            bpm: bpm,
            date: latestSample.startDate,
            source: "watch"
        )

        latestHeartRate = bpm
        lastUpdated = latestSample.startDate
        error = nil

        // Forward to connectivity layer
        onNewHeartRate?(sample)
    }
}
