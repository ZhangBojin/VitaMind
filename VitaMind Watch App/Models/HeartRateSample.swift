import Foundation

/// A single heart rate reading, shared between watch and iPhone targets.
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
}
