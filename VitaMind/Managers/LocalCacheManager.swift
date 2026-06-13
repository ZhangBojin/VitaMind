import Foundation

/// Simple JSON-file-based persistence for all health metric types.
/// Stores a dictionary of `[HealthMetricType: [HealthSample]]` to disk
/// so data survives across launches.
@MainActor
final class LocalCacheManager {
    private let fileName = "health_samples_cache.json"
    private let maxSamplesPerType = 500

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent(fileName)
    }

    // MARK: - Public API

    /// Load all cached samples from disk. Returns empty dictionary if no cache exists.
    func loadAll() -> [HealthMetricType: [HealthSample]] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: fileURL)
            // HealthMetricType is RawRepresentable (String), so encode/decode via [String: [HealthSample]]
            let raw = try JSONDecoder().decode([String: [HealthSample]].self, from: data)
            var result: [HealthMetricType: [HealthSample]] = [:]
            for (key, samples) in raw {
                guard let type = HealthMetricType(rawValue: key) else { continue }
                result[type] = samples
            }
            return result
        } catch {
            print("[LocalCacheManager] Load failed: \(error.localizedDescription)")
            return [:]
        }
    }

    /// Load cached samples for a single metric type.
    func load(for type: HealthMetricType) -> [HealthSample] {
        loadAll()[type] ?? []
    }

    /// Save all samples to disk, trimming each type to `maxSamplesPerType`.
    func saveAll(_ data: [HealthMetricType: [HealthSample]]) {
        var raw: [String: [HealthSample]] = [:]
        for (type, samples) in data {
            raw[type.rawValue] = Array(samples.prefix(maxSamplesPerType))
        }
        do {
            let jsonData = try JSONEncoder().encode(raw)
            try jsonData.write(to: fileURL, options: .atomic)
        } catch {
            print("[LocalCacheManager] Save failed: \(error.localizedDescription)")
        }
    }

    /// Save samples for a single metric type, merging with existing data.
    func save(_ samples: [HealthSample], for type: HealthMetricType) {
        var all = loadAll()
        all[type] = Array(samples.prefix(maxSamplesPerType))
        saveAll(all)
    }

    /// Remove all cached data.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
