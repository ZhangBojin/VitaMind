import Foundation
import Observation

@MainActor
@Observable
final class VitalsViewModel {
    private(set) var bloodOxygenSamples: [HealthSample] = []
    private(set) var respiratoryRateSamples: [HealthSample] = []

    private(set) var latestSpO2: Double?
    private(set) var averageSpO2: Double?
    private(set) var minSpO2: Double?
    private(set) var maxSpO2: Double?

    private(set) var latestRespiratoryRate: Double?
    private(set) var averageRespiratoryRate: Double?

    private(set) var isLoading = false
    private(set) var error: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
        updateStats()
    }

    func updateStats() {
        error = healthKitManager.error

        bloodOxygenSamples = healthKitManager.allSamples[.bloodOxygen] ?? []
        respiratoryRateSamples = healthKitManager.allSamples[.respiratoryRate] ?? []

        // SpO2 stats (values are fractions like 0.95–1.00; display as %)
        if !bloodOxygenSamples.isEmpty {
            let values = bloodOxygenSamples.map(\.value)
            latestSpO2 = values.first
            averageSpO2 = values.reduce(0, +) / Double(values.count)
            minSpO2 = values.min()
            maxSpO2 = values.max()
        }

        // Respiratory rate stats
        if !respiratoryRateSamples.isEmpty {
            let values = respiratoryRateSamples.map(\.value)
            latestRespiratoryRate = values.first
            averageRespiratoryRate = values.reduce(0, +) / Double(values.count)
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
