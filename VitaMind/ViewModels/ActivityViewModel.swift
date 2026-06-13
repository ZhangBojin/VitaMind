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

        // Today's aggregates from cumulative quantities
        todaySteps = aggregateToday(type: .steps, since: todayStart)
        activeCalories = aggregateTodayCalories(since: todayStart)

        // Exercise minutes: cumulative type, take max value
        if let samples = healthKitManager.allSamples[.exerciseMinutes] {
            let todaySamples = samples.filter { $0.date >= todayStart }
            exerciseMinutes = Int(todaySamples.map(\.value).max() ?? 0)
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

    private func aggregateToday(type: HealthMetricType, since start: Date) -> Int {
        guard let samples = healthKitManager.allSamples[type] else { return 0 }
        let todaySamples = samples.filter { $0.date >= start }
        return Int(todaySamples.reduce(0) { $0 + $1.value })
    }

    private func aggregateTodayCalories(since start: Date) -> Double {
        guard let samples = healthKitManager.allSamples[.activeEnergy] else { return 0 }
        let todaySamples = samples.filter { $0.date >= start }
        return todaySamples.reduce(0) { $0 + $1.value }
    }

    private func computeStepHistory(days: Int) -> [(label: String, steps: Int)] {
        guard let samples = healthKitManager.allSamples[.steps] else { return [] }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Mon, Tue, etc.
        var history: [(label: String, steps: Int)] = []

        for dayOffset in (0..<days).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date())) else {
                continue
            }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let daySamples = samples.filter { $0.date >= dayStart && $0.date < dayEnd }
            let totalSteps = Int(daySamples.reduce(0) { $0 + $1.value })
            let label = formatter.string(from: dayStart)
            history.append((label: label, steps: totalSteps))
        }

        return history
    }
}
