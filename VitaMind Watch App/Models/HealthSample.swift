import Foundation

/// A generic health data sample that represents any HealthKit metric.
/// Replaces the heart-rate-specific `HeartRateSample` with a type-driven model
/// that works for heart rate, HRV, steps, sleep, blood oxygen, etc.
struct HealthSample: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let type: HealthMetricType
    let value: Double
    let unit: String
    let date: Date
    /// Source of the reading: "watch", "iphone", or the device name from HealthKit.
    let source: String
    /// Optional metadata, e.g. sleep stage labels, workout info.
    let metadata: [String: String]?

    init(
        id: UUID = UUID(),
        type: HealthMetricType,
        value: Double,
        unit: String? = nil,
        date: Date,
        source: String = "watch",
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.unit = unit ?? type.unit
        self.date = date
        self.source = source
        self.metadata = metadata
    }
}
