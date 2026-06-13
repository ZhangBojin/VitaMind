import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    var latestHeartRate: Double?
    var averageHeartRate: Double?
    var minHeartRate: Double?
    var maxHeartRate: Double?
    var recentSamples: [HeartRateSample] = []
    var isLoading = false
    var error: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        updateStats()
    }

    /// Recompute stats from the HealthKit manager's samples.
    func updateStats() {
        let samples = healthKitManager.heartRateSamples
        recentSamples = Array(samples.prefix(50)) // last 50 readings

        guard !samples.isEmpty else { return }

        let bpms = samples.map(\.bpm)
        latestHeartRate = bpms.first
        averageHeartRate = bpms.reduce(0, +) / Double(bpms.count)
        minHeartRate = bpms.min()
        maxHeartRate = bpms.max()
        error = healthKitManager.error
    }

    /// Refresh data — re-fetch the last 7 days.
    func refresh() async {
        isLoading = true
        await healthKitManager.fetchHeartRateSamples(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
        updateStats()
        isLoading = false
    }
}
