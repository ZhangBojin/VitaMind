import Foundation
import Observation

@MainActor
@Observable
final class ActivityViewModel {
    private(set) var todaySteps: Int = 0
    private(set) var stepGoal: Int = 10000
    private(set) var activeCalories: Double = 0
    private(set) var exerciseMinutes: Int = 0
    private(set) var standHours: Int = 0
    private(set) var standGoal: Int = 12

    /// Daily step history (last 7 days), newest first.
    private(set) var stepHistory: [(label: String, steps: Int)] = []

    private(set) var isLoading = false
    private(set) var error: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        updateStats()
    }

    func updateStats() {
        error = healthKitManager.error

        let todayStart = Calendar.current.startOfDay(for: Date())

        // Use HKStatisticsQuery for accurate cumulative totals matching Health.app.
        Task {
            if let s = await healthKitManager.fetchDailyCumulativeSum(for: .steps) { todaySteps = Int(s) }
            if let c = await healthKitManager.fetchDailyCumulativeSum(for: .activeEnergy) { activeCalories = c }
            if let m = await healthKitManager.fetchDailyCumulativeSum(for: .exerciseMinutes) { exerciseMinutes = Int(m) }
        }

        // Stand hours: count hours where stand was achieved
        if let samples = healthKitManager.allSamples[.standHours] {
            standHours = samples.filter { $0.date >= todayStart && $0.value > 0 }.count
        }

        // Compute 7-day step history
        stepHistory = computeStepHistory(days: 7)
    }

    func refresh() async {
        isLoading = true
        await healthKitManager.fetchAllSamples(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
        updateStats()
        isLoading = false
    }

    // MARK: - Private

    private func computeStepHistory(days: Int) -> [(label: String, steps: Int)] {
        guard let samples = healthKitManager.allSamples[.steps] else { return [] }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        var history: [(label: String, steps: Int)] = []

        for dayOffset in (0..<days).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date())) else {
                continue
            }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let daySamples = samples.filter { $0.date >= dayStart && $0.date < dayEnd }
            // Cumulative type: latest value = total for the day.
            let daySteps = Int(daySamples.map(\.value).max() ?? 0)
            let label = formatter.string(from: dayStart)
            history.append((label: label, steps: daySteps))
        }

        return history
    }
}
