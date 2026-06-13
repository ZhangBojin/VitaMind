import SwiftUI

struct StepsWatchView: View {
    @Environment(WatchHealthKitManager.self) private var healthKitManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "shoeprints.fill")
                .font(.title2)
                .foregroundStyle(.green)

            if let steps = healthKitManager.todaySteps {
                Text("\(Int(steps))")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                Text("今日步数")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let energy = healthKitManager.todayActiveEnergy {
                    Text("\(Int(energy)) 千卡")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("--")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("暂无步数数据")
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
        .onAppear {
            Task {
                await healthKitManager.requestAuthorization()
                healthKitManager.startObservingAll()
            }
        }
        .onDisappear {
            healthKitManager.stopObserving()
        }
    }
}
