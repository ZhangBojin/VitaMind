import Foundation

/// A single heart rate reading, used across the app for display and persistence.
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
}
