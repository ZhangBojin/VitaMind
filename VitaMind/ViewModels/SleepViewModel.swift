import Foundation
import Observation

@MainActor
@Observable
final class SleepViewModel {
    private(set) var lastNightSamples: [HealthSample] = []
    private(set) var totalSleepHours: Double = 0
    private(set) var deepSleepHours: Double = 0
    private(set) var coreSleepHours: Double = 0
    private(set) var remSleepHours: Double = 0
    private(set) var awakeTime: Double = 0
    private(set) var inBedTime: Double = 0

    /// Weekly sleep averages: [(dayLabel, hours)]
    private(set) var weeklyAverages: [(label: String, hours: Double)] = []

    private(set) var isLoading = false
    private(set) var error: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        updateStats()
    }

    func updateStats() {
        error = healthKitManager.error

        guard let samples = healthKitManager.allSamples[.sleepAnalysis], !samples.isEmpty else {
            return
        }

        // Find last night's sleep samples (roughly 6 PM yesterday to now)
        let now = Date()
        let calendar = Calendar.current
        let yesterday6PM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!) ?? Date().addingTimeInterval(-86400)

        lastNightSamples = samples
            .filter { $0.date >= yesterday6PM && $0.date <= now }
            .sorted { $0.date < $1.date }

        // Aggregate by stage
        totalSleepHours = 0
        deepSleepHours = 0
        coreSleepHours = 0
        remSleepHours = 0
        awakeTime = 0
        inBedTime = 0

        for sample in lastNightSamples {
            let hours = sample.value
            let stage = sample.metadata?["stage"] ?? "unknown"
            switch stage {
            case "deep":
                deepSleepHours += hours
                totalSleepHours += hours
            case "core":
                coreSleepHours += hours
                totalSleepHours += hours
            case "rem":
                remSleepHours += hours
                totalSleepHours += hours
            case "awake":
                awakeTime += hours
            case "inBed":
                inBedTime += hours
            case "asleep":
                totalSleepHours += hours
            default:
                totalSleepHours += hours
            }
        }

        // Compute weekly averages
        weeklyAverages = computeWeeklyAverages(samples: samples)
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

    private func computeWeeklyAverages(samples: [HealthSample]) -> [(label: String, hours: Double)] {
        let calendar = Calendar.current
        var averages: [(label: String, hours: Double)] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "E" // Mon, Tue, etc.

        for dayOffset in (1...7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date())) else {
                continue
            }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let daySamples = samples.filter { $0.date >= dayStart && $0.date < dayEnd }
            let total = daySamples.reduce(0) { $0 + $1.value }
            let label = formatter.string(from: dayStart)
            averages.append((label: label, hours: total))
        }

        return averages
    }
}
