import Foundation
import Observation

@MainActor
@Observable
final class HeartViewModel {
    private(set) var heartRateSamples: [HealthSample] = []
    private(set) var hrvSamples: [HealthSample] = []
    private(set) var restingHeartRate: Double?
    private(set) var walkingHeartRateAvg: Double?

    private(set) var currentHeartRate: Double?
    private(set) var averageHRV: Double?
    private(set) var minHeartRate: Double?
    private(set) var maxHeartRate: Double?

    private(set) var isLoading = false
    private(set) var error: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        updateStats()
    }

    func updateStats() {
        error = healthKitManager.error

        heartRateSamples = healthKitManager.allSamples[.heartRate] ?? []
        hrvSamples = healthKitManager.allSamples[.heartRateVariability] ?? []

        // Resting & walking heart rate
        if let restingSamples = healthKitManager.allSamples[.restingHeartRate], let first = restingSamples.first {
            restingHeartRate = first.value
        }
        if let walkingSamples = healthKitManager.allSamples[.walkingHeartRateAverage], let first = walkingSamples.first {
            walkingHeartRateAvg = first.value
        }

        // Heart rate stats
        if !heartRateSamples.isEmpty {
            let bpms = heartRateSamples.map(\.value)
            currentHeartRate = bpms.first
            minHeartRate = bpms.min()
            maxHeartRate = bpms.max()
        }

        // HRV stats
        if !hrvSamples.isEmpty {
            let values = hrvSamples.map(\.value)
            averageHRV = values.reduce(0, +) / Double(values.count)
        }
    }

    func refresh() async {
        isLoading = true
        await healthKitManager.fetchAllSamples(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
        updateStats()
        isLoading = false
    }
}
