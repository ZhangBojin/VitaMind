import Foundation

/// A single heart rate reading, shared between watch and iPhone targets.
/// Deprecated: Use `HealthSample` with `type: .heartRate` instead.
@available(*, deprecated, message: "Use HealthSample with type .heartRate instead")
struct HeartRateSample: Identifiable, Codable, Equatable {
    let id: UUID
    let bpm: Double
    let date: Date
    let source: String

    init(id: UUID = UUID(), bpm: Double, date: Date, source: String = "watch") {
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
