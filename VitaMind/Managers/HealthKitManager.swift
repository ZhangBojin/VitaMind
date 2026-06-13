import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class HealthKitManager {
    // MARK: - Published state

    private(set) var isAuthorized = false
    /// All samples keyed by metric type, sorted newest-first.
    private(set) var allSamples: [HealthMetricType: [HealthSample]] = [:]
    /// Latest value for each metric type.
    private(set) var latestValues: [HealthMetricType: Double] = [:]
    private(set) var error: String?

    // MARK: - Backward-compat computed properties

    var latestHeartRate: Double? { latestValues[.heartRate] }
    var heartRateSamples: [HealthSample] { allSamples[.heartRate] ?? [] }

    // MARK: - Private

    private let healthStore = HKHealthStore()
    private let cache = LocalCacheManager()
    private var observerQueries: [HealthMetricType: HKObserverQuery] = [:]

    /// All HealthKit types the app reads.
    static let allReadTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        for metricType in HealthMetricType.allCases {
            if let objType = metricType.hkObjectType {
                types.insert(objType)
            }
        }
        return types
    }()

    // MARK: - Init

    init() {
        // Restore previously cached samples so the UI shows data immediately.
        let cached = cache.loadAll()
        if !cached.isEmpty {
            allSamples = cached
            for (type, samples) in cached {
                if let first = samples.first {
                    latestValues[type] = first.value
                }
            }
        }
    }

    // MARK: - Cache Integration

    /// Merge externally-provided samples (e.g., from Watch) into the local dataset.
    func ingestWatchSamples(_ incoming: [HealthSample]) {
        for sample in incoming {
            ingestSingleSample(sample)
        }
    }

    /// Ingest a single sample from an external source (e.g., WatchConnectivity).
    func ingestSingleSample(_ sample: HealthSample) {
        var existing = allSamples[sample.type] ?? []
        let existingIDs = Set(existing.map(\.id))
        guard !existingIDs.contains(sample.id) else { return }

        existing.append(sample)
        existing.sort { $0.date > $1.date }
        allSamples[sample.type] = existing
        latestValues[sample.type] = existing.first?.value
        cache.saveAll(allSamples)
    }

    // MARK: - Authorization

    /// Request HealthKit authorization to read all supported health data types.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = "此设备不支持 HealthKit。"
            return
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: Self.allReadTypes)
            isAuthorized = true
            error = nil
        } catch {
            self.error = "健康数据授权失败: \(error.localizedDescription)"
            isAuthorized = false
        }
    }

    // MARK: - Data Fetching

    /// Fetch samples for a single metric type over a date range.
    func fetchSamples(for type: HealthMetricType, from startDate: Date, to endDate: Date = Date()) async {
        guard isAuthorized else {
            error = "HealthKit 未授权，请先调用 requestAuthorization()。"
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        do {
            let samples = try await fetchSamplesInternal(type: type, predicate: predicate)
            allSamples[type] = samples
            if let first = samples.first {
                latestValues[type] = first.value
            }
            error = nil
            cache.saveAll(allSamples)
        } catch {
            self.error = "获取\(type.displayName)数据失败: \(error.localizedDescription)"
        }
    }

    /// Fetch all supported metric types concurrently over a date range.
    func fetchAllSamples(from startDate: Date, to endDate: Date = Date()) async {
        guard isAuthorized else {
            error = "HealthKit 未授权，请先调用 requestAuthorization()。"
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        await withTaskGroup(of: (HealthMetricType, [HealthSample])?.self) { group in
            for type in HealthMetricType.allCases {
                group.addTask { @MainActor in
                    do {
                        let samples = try await self.fetchSamplesInternal(type: type, predicate: predicate)
                        return (type, samples)
                    } catch {
                        print("[HealthKitManager] Fetch \(type.displayName) failed: \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            for await result in group {
                guard let (type, samples) = result else { continue }
                allSamples[type] = samples
                if let first = samples.first {
                    latestValues[type] = first.value
                }
            }
        }

        error = nil
        cache.saveAll(allSamples)
    }

    // MARK: - Observers

    /// Start observer queries for all quantity-based metric types.
    /// Category types (sleep, standHours) are fetched periodically instead.
    func startAllObservers() {
        guard isAuthorized else { return }

        for type in HealthMetricType.allCases {
            guard let quantityTypeID = type.hkQuantityTypeIdentifier,
                  let sampleType = type.hkObjectType as? HKSampleType else {
                continue
            }

            #if os(watchOS)
            if type == .heartRate || type == .heartRateVariability {
                let frequency: HKUpdateFrequency = type == .heartRate ? .immediate : .hourly
                healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { _, error in
                    if let error {
                        Task { @MainActor in
                            print("[HealthKitManager] Background delivery for \(type.displayName): \(error.localizedDescription)")
                        }
                    }
                }
            }
            #endif

            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, err in
                defer { completionHandler() }
                if let err {
                    Task { @MainActor in
                        self?.error = "观察器错误(\(type.displayName)): \(err.localizedDescription)"
                    }
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.fetchLatest(for: type)
                }
            }

            observerQueries[type] = query
            healthStore.execute(query)
        }
    }

    /// Stop all observer queries.
    func stopAllObservers() {
        for (_, query) in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
    }

    // MARK: - Private Helpers

    /// Fetch the latest samples for a single type (called by observer queries).
    private func fetchLatest(for type: HealthMetricType) async {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-3600),
            end: Date(),
            options: .strictStartDate
        )

        do {
            let newSamples = try await fetchSamplesInternal(type: type, predicate: predicate)
            var existing = allSamples[type] ?? []
            let existingIDs = Set(existing.map(\.id))
            let uniqueNew = newSamples.filter { !existingIDs.contains($0.id) }
            guard !uniqueNew.isEmpty else { return }

            existing = (uniqueNew + existing).sorted { $0.date > $1.date }
            allSamples[type] = existing
            if let first = existing.first {
                latestValues[type] = first.value
            }
            cache.saveAll(allSamples)
            error = nil
        } catch {
            print("[HealthKitManager] fetchLatest(\(type.displayName)): \(error.localizedDescription)")
        }
    }

    /// Internal fetch dispatcher that handles quantity vs category types.
    private func fetchSamplesInternal(type: HealthMetricType, predicate: NSPredicate) async throws -> [HealthSample] {
        if let _ = type.hkQuantityTypeIdentifier {
            return try await fetchQuantitySamples(type: type, predicate: predicate)
        }
        if let categoryID = type.hkCategoryTypeIdentifier {
            switch categoryID {
            case .appleStandHour:
                return try await fetchStandHourSamples(predicate: predicate)
            case .sleepAnalysis:
                return try await fetchSleepSamples(predicate: predicate)
            default:
                return []
            }
        }
        return []
    }

    /// Fetch quantity-based samples (heart rate, HRV, steps, energy, etc.).
    private func fetchQuantitySamples(type: HealthMetricType, predicate: NSPredicate) async throws -> [HealthSample] {
        guard let quantityTypeID = type.hkQuantityTypeIdentifier,
              let quantityType = HKQuantityType.quantityType(forIdentifier: quantityTypeID) else {
            return []
        }

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: quantityType,
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

        return samples
            .compactMap { $0 as? HKQuantitySample }
            .map { sample in
                HealthSample(
                    type: type,
                    value: sample.quantity.doubleValue(for: type.hkUnit),
                    date: sample.startDate,
                    source: sample.sourceRevision.source.name
                )
            }
    }

    /// Fetch stand hour category samples.
    /// Maps HKCategoryValueAppleStandHour.stood → value 1.0, .idle → value 0.0.
    private func fetchStandHourSamples(predicate: NSPredicate) async throws -> [HealthSample] {
        guard let categoryType = HKCategoryType.categoryType(forIdentifier: .appleStandHour) else {
            return []
        }

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: categoryType,
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

        return samples.compactMap { sample in
            guard let categorySample = sample as? HKCategorySample else { return nil }
            let value: Double = categorySample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1.0 : 0.0
            return HealthSample(
                type: .standHours,
                value: value,
                date: categorySample.startDate,
                source: categorySample.sourceRevision.source.name
            )
        }
    }

    /// Fetch sleep analysis category samples with stage labels in metadata.
    private func fetchSleepSamples(predicate: NSPredicate) async throws -> [HealthSample] {
        guard let categoryType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: categoryType,
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

        return samples.compactMap { sample in
            guard let categorySample = sample as? HKCategorySample else { return nil }
            let duration = categorySample.endDate.timeIntervalSince(categorySample.startDate) / 3600.0 // hours
            let stageName = sleepStageName(for: categorySample.value)
            return HealthSample(
                type: .sleepAnalysis,
                value: max(0, duration),
                date: categorySample.startDate,
                source: categorySample.sourceRevision.source.name,
                metadata: ["stage": stageName]
            )
        }
    }

    private func sleepStageName(for value: Int) -> String {
        // HKCategoryValueSleepAnalysis values (available from iOS 16+)
        // 0 = inBed, 1 = asleepUnspecified, 2 = awake, 3 = deep, 4 = core, 5 = rem
        switch value {
        case 0:  return "inBed"
        case 1:  return "asleep"
        case 2:  return "awake"
        case 3:  return "deep"
        case 4:  return "core"
        case 5:  return "rem"
        default: return "unknown"
        }
    }
}
