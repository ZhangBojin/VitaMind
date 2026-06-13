import Foundation
import Observation

@MainActor
@Observable
final class DashboardViewModel {
    // Stress
    private(set) var stressScore: Int?
    private(set) var latestSDNN: Double?
    private(set) var stressLevelText: String = "暂无数据"
    private(set) var lastStressUpdated: Date?

    // Watch diagnostics
    private(set) var watchHKAuthorized: Bool?
    private(set) var watchMonitoring: Bool?
    private(set) var watchErrorText: String?
    private(set) var watchLastReport: Date?

    // Heart
    private(set) var currentHeartRate: Double?
    private(set) var latestHRV: Double?

    // Activity
    private(set) var todaySteps: Int = 0
    private(set) var todayCalories: Double = 0
    private(set) var todayExerciseMinutes: Int = 0
    private(set) var todayStandHours: Int = 0
    private(set) var standGoal: Int = 12

    // Sleep
    private(set) var lastNightSleepHours: Double = 0

    // Vitals
    private(set) var latestSpO2: Double?
    private(set) var latestRespiratoryRate: Double?

    private(set) var isLoading = false
    private(set) var error: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        updateStats()
    }

    /// Recompute stats from the HealthKit manager's samples.
    func updateStats() {
        error = healthKitManager.error

        // Stress
        stressScore = healthKitManager.latestStressScore
        latestSDNN = healthKitManager.latestSDNN
        stressLevelText = stressLevelDisplayName(healthKitManager.stressLevel)
        lastStressUpdated = healthKitManager.lastStressUpdated

        // Watch diagnostics
        watchHKAuthorized = healthKitManager.watchStatus.healthKitAuthorized
        watchMonitoring = healthKitManager.watchStatus.stressMonitoring
        watchErrorText = healthKitManager.watchStatus.errorText
        watchLastReport = healthKitManager.watchStatus.lastReportTime

        // Heart
        if let hrSamples = healthKitManager.allSamples[.heartRate], let first = hrSamples.first {
            currentHeartRate = first.value
        }
        if let hrvSamples = healthKitManager.allSamples[.heartRateVariability], let first = hrvSamples.first {
            latestHRV = first.value
        }

        // Activity — aggregate today's values
        let todayStart = Calendar.current.startOfDay(for: Date())
        todaySteps = aggregateToday(type: .steps, since: todayStart)
        todayCalories = aggregateTodayDouble(type: .activeEnergy, since: todayStart)
        todayExerciseMinutes = aggregateTodayMinutes(type: .exerciseMinutes, since: todayStart)
        todayStandHours = countTodayStandHours(since: todayStart)

        // Sleep — sum last night's sleep
        lastNightSleepHours = computeLastNightSleep()

        // Vitals
        if let spO2Samples = healthKitManager.allSamples[.bloodOxygen], let first = spO2Samples.first {
            latestSpO2 = first.value
        }
        if let respSamples = healthKitManager.allSamples[.respiratoryRate], let first = respSamples.first {
            latestRespiratoryRate = first.value
        }
    }

    /// Refresh data — re-fetch the last 7 days for all types.
    func refresh() async {
        isLoading = true
        await healthKitManager.fetchAllSamples(
            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        )
        updateStats()
        isLoading = false
    }

    // MARK: - Private Helpers

    private func aggregateToday(type: HealthMetricType, since start: Date) -> Int {
        guard let samples = healthKitManager.allSamples[type] else { return 0 }
        let todaySamples = samples.filter { $0.date >= start }
        return Int(todaySamples.reduce(0) { $0 + $1.value })
    }

    private func aggregateTodayDouble(type: HealthMetricType, since start: Date) -> Double {
        guard let samples = healthKitManager.allSamples[type] else { return 0 }
        let todaySamples = samples.filter { $0.date >= start }
        return todaySamples.reduce(0) { $0 + $1.value }
    }

    private func aggregateTodayMinutes(type: HealthMetricType, since start: Date) -> Int {
        guard let samples = healthKitManager.allSamples[type] else { return 0 }
        let todaySamples = samples.filter { $0.date >= start }
        // Exercise minutes from HealthKit are cumulative; take the max value
        return Int(todaySamples.map(\.value).max() ?? 0)
    }

    private func stressLevelDisplayName(_ level: String) -> String {
        switch level {
        case "relaxed": return "放松"
        case "normal":  return "正常"
        case "alert":   return "注意"
        case "tense":   return "紧张"
        default:        return "暂无数据"
        }
    }

    private func countTodayStandHours(since start: Date) -> Int {
        guard let samples = healthKitManager.allSamples[.standHours] else { return 0 }
        let todaySamples = samples.filter { $0.date >= start && $0.value > 0 }
        return todaySamples.count
    }

    private func computeLastNightSleep() -> Double {
        guard let samples = healthKitManager.allSamples[.sleepAnalysis] else { return 0 }
        // Find sleep samples from the most recent night (6 PM yesterday to now)
        let now = Date()
        let calendar = Calendar.current
        let yesterday6PM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!) ?? now
        let recentSleep = samples.filter { $0.date >= yesterday6PM && $0.date <= now }
        return recentSleep.reduce(0) { $0 + $1.value }
    }
}
