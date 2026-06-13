import SwiftUI

struct HeartRateView: View {
    @Environment(WatchHealthKitManager.self) private var healthKitManager

    var body: some View {
        VStack(spacing: 12) {
            // Heart icon
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundStyle(.red)

            // Current BPM
            if let bpm = healthKitManager.latestHeartRate {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(bpm))")
                        .font(.system(size: 56, weight: .thin, design: .rounded))
                    Text("BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // Last updated
            if let lastUpdated = healthKitManager.lastUpdated {
                Text("Updated \(lastUpdated, style: .time)")
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
                Text("Open iPhone app to\ngrant Health access")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .onAppear {
            Task {
                await healthKitManager.requestAuthorization()
                healthKitManager.startObserving()
            }
        }
        .onDisappear {
            healthKitManager.stopObserving()
        }
    }
}

#Preview {
    HeartRateView()
        .environment(WatchHealthKitManager())
}
