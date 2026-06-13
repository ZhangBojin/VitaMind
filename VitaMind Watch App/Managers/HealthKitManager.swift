import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class WatchHealthKitManager {
    // MARK: - Published state

    private(set) var isAuthorized = false
    private(set) var latestHeartRate: Double?
    private(set) var latestHRV: Double?
    private(set) var todaySteps: Double?
    private(set) var todayActiveEnergy: Double?
    private(set) var lastUpdated: Date?
    private(set) var error: String?

    /// Callback invoked each time a new health sample arrives.
    /// The WatchConnectivity manager uses this to forward data to the phone.
    var onNewSample: ((HealthSample) -> Void)?

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

    private var heartRateObserver: HKObserverQuery?
    private var hrvObserver: HKObserverQuery?
    private var collectionTimer: Timer?

    /// All read types for watch HealthKit authorization.
    static let watchReadTypes: Set<HKObjectType> = {
        let ids: [HKQuantityTypeIdentifier] = [
            .heartRate, .heartRateVariabilitySDNN, .stepCount, .activeEnergyBurned
        ]
        return Set(ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }()

    // MARK: - Authorization

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "此设备不支持 HealthKit。"
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: Self.watchReadTypes)
            isAuthorized = true
            error = nil
        } catch {
            self.error = "授权失败: \(error.localizedDescription)"
            isAuthorized = false
        }
    }

    // MARK: - Observation

    /// Begin observing heart rate and HRV, plus periodic step/energy collection.
    func startObservingAll() {
        guard isAuthorized else { return }

        // Heart rate: immediate background delivery
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { _, error in
            if let error {
                Task { @MainActor in
                    self.error = "Background delivery (HR): \(error.localizedDescription)"
                }
            }
        }

        heartRateObserver = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            if let error {
                Task { @MainActor in
                    self?.error = "Observer error (HR): \(error.localizedDescription)"
                }
                return
            }
            Task { @MainActor [weak self] in
                await self?.fetchLatestHeartRate()
            }
        }
        if let heartRateObserver {
            healthStore.execute(heartRateObserver)
        }

        // HRV: hourly background delivery (less frequent, saves battery)
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .hourly) { _, error in
            if let error {
                Task { @MainActor in
                    print("[Watch HK] Background delivery (HRV): \(error.localizedDescription)")
                }
            }
        }

        hrvObserver = HKObserverQuery(sampleType: hrvType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            if let error {
                Task { @MainActor in
                    print("[Watch HK] Observer error (HRV): \(error.localizedDescription)")
                }
                return
            }
            Task { @MainActor [weak self] in
                await self?.fetchLatestHRV()
            }
        }
        if let hrvObserver {
            healthStore.execute(hrvObserver)
        }

        // Immediate fetches
        Task {
            await fetchLatestHeartRate()
            await fetchLatestHRV()
            await fetchTodaySteps()
            await fetchTodayActiveEnergy()
        }

        // Periodic timer for steps and active energy (every 10 minutes)
        collectionTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchTodaySteps()
                await self?.fetchTodayActiveEnergy()
            }
        }
    }

    func stopObserving() {
        if let heartRateObserver {
            healthStore.stop(heartRateObserver)
            self.heartRateObserver = nil
        }
        if let hrvObserver {
            healthStore.stop(hrvObserver)
            self.hrvObserver = nil
        }
        collectionTimer?.invalidate()
        collectionTimer = nil
    }

    // MARK: - Private Fetch Methods

    private func fetchLatestHeartRate() async {
        let sample = await fetchLatestQuantity(type: heartRateType, unit: HKUnit(from: "count/min"))
        guard let sample else { return }

        let healthSample = HealthSample(
            type: .heartRate,
            value: sample.quantity.doubleValue(for: HKUnit(from: "count/min")),
            date: sample.startDate,
            source: "watch"
        )

        latestHeartRate = healthSample.value
        lastUpdated = sample.startDate
        error = nil
        onNewSample?(healthSample)
    }

    private func fetchLatestHRV() async {
        let sample = await fetchLatestQuantity(type: hrvType, unit: HKUnit(from: "ms"))
        guard let sample else { return }

        let healthSample = HealthSample(
            type: .heartRateVariability,
            value: sample.quantity.doubleValue(for: HKUnit(from: "ms")),
            date: sample.startDate,
            source: "watch"
        )

        latestHRV = healthSample.value
        lastUpdated = sample.startDate
        error = nil
        onNewSample?(healthSample)
    }

    private func fetchTodaySteps() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let total = await fetchSumQuantity(type: stepType, unit: HKUnit.count(), from: startOfDay, to: Date())
        todaySteps = total

        if let steps = total {
            let healthSample = HealthSample(
                type: .steps,
                value: steps,
                date: Date(),
                source: "watch"
            )
            onNewSample?(healthSample)
        }
    }

    private func fetchTodayActiveEnergy() async {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let total = await fetchSumQuantity(type: activeEnergyType, unit: HKUnit.kilocalorie(), from: startOfDay, to: Date())
        todayActiveEnergy = total

        if let energy = total {
            let healthSample = HealthSample(
                type: .activeEnergy,
                value: energy,
                date: Date(),
                source: "watch"
            )
            onNewSample?(healthSample)
        }
    }

    // MARK: - Generic Fetch Helpers

    /// Fetch the single most recent quantity sample for a type.
    private func fetchLatestQuantity(type: HKQuantityType, unit: HKUnit) async -> HKQuantitySample? {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-600),
            end: Date(),
            options: .strictStartDate
        )

        let samples: [HKSample]
        do {
            samples = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: type,
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
            print("[Watch HK] fetchLatestQuantity failed: \(error.localizedDescription)")
            return nil
        }

        return samples
            .compactMap { $0 as? HKQuantitySample }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    /// Fetch the cumulative sum for a quantity type over a date range.
    private func fetchSumQuantity(type: HKQuantityType, unit: HKUnit, from startDate: Date, to endDate: Date) async -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        do {
            let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: type,
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

            let total = samples
                .compactMap { $0 as? HKQuantitySample }
                .reduce(0) { $0 + $1.quantity.doubleValue(for: unit) }
            return total
        } catch {
            print("[Watch HK] fetchSumQuantity failed: \(error.localizedDescription)")
            return nil
        }
    }
}
