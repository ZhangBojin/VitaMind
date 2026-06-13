import SwiftUI

struct HeartRateView: View {
    @Environment(WatchHealthKitManager.self) private var healthKitManager

    var body: some View {
        VStack(spacing: 12) {
            // Heart icon
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)

            // Current BPM
            if let bpm = healthKitManager.latestHeartRate {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(bpm))")
                        .font(.system(size: 56, weight: .thin, design: .rounded))
                    Text("次/分")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // Last updated
            if let lastUpdated = healthKitManager.lastUpdatedHeartRate {
                Text("更新于 \(lastUpdated, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Status
            if let error = healthKitManager.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if !healthKitManager.isAuthorized {
                Text("请打开 iPhone App\n授予健康访问权限")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    HeartRateView()
        .environment(WatchHealthKitManager())
}
