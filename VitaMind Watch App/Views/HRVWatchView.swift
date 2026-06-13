import SwiftUI

struct HRVWatchView: View {
    @Environment(WatchHealthKitManager.self) private var healthKitManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(.purple)

            if let hrv = healthKitManager.latestHRV {
                Text("\(Int(hrv))")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                Text("毫秒")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let updated = healthKitManager.lastUpdatedHRV {
                    Text("更新于 \(updated, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("暂无心率变异性数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = healthKitManager.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            } else if !healthKitManager.isAuthorized {
                Text("请打开 iPhone App\n授予健康访问权限")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
}
