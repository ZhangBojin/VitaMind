import Foundation

/// Simple JSON-file-based persistence for heart rate samples.
/// Saves to the app's Documents directory so data survives across launches.
@MainActor
final class LocalCacheManager {
    private let fileName = "heart_rate_samples.json"
    private let maxStoredSamples = 1000

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    // MARK: - Public API

    /// Load cached samples from disk. Returns empty array if no cache exists.
    func load() -> [HeartRateSample] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let samples = try JSONDecoder().decode([HeartRateSample].self, from: data)
            return samples
        } catch {
            print("[LocalCacheManager] Load failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Save samples to disk, trimming to `maxStoredSamples`.
    func save(_ samples: [HeartRateSample]) {
        let trimmed = Array(samples.prefix(maxStoredSamples))
        do {
            let data = try JSONEncoder().encode(trimmed)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[LocalCacheManager] Save failed: \(error.localizedDescription)")
        }
    }

    /// Remove all cached data.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
