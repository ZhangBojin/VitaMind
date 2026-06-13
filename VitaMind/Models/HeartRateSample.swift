import Foundation

/// A single heart rate reading, used across the app for display and persistence.
/// Deprecated: Use `HealthSample` with `type: .heartRate` instead.
/// This type remains for backward compatibility during migration.
@available(*, deprecated, message: "Use HealthSample with type .heartRate instead")
struct HeartRateSample: Identifiable, Codable, Equatable {
    let id: UUID
    let bpm: Double
    let date: Date
    /// Source of the reading: "watch" or "iphone"
    let source: String

    init(id: UUID = UUID(), bpm: Double, date: Date, source: String = "iphone") {
        self.id = id
        self.bpm = bpm
        self.date = date
        self.source = source
    }

    /// Convert from the new generic HealthSample model.
    init(from healthSample: HealthSample) {
        self.id = healthSample.id
        self.bpm = healthSample.value
        self.date = healthSample.date
        self.source = healthSample.source
    }

    /// Convert to the new generic HealthSample model.
    var toHealthSample: HealthSample {
        HealthSample(
            id: id,
            type: .heartRate,
            value: bpm,
            unit: "BPM",
            date: date,
            source: source
        )
    }
}
