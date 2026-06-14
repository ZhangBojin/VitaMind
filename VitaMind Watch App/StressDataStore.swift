import Foundation

/// Shared data store bridging StressMonitor → ComplicationController.
/// Updated by StressMonitor, read by the watch face complication.
@MainActor
final class StressDataStore {
    static let shared = StressDataStore()
    var latestScore: Int?
    var latestLevel: String = "unknown"
    private init() {}
}
