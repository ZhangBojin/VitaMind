import SwiftUI

struct DashboardOverviewView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(WatchConnectivityManager.self) private var watchConnectivity
    let viewModel: DashboardViewModel

    var body: some View {
        if !healthKitManager.isAuthorized {
            HealthAuthorizationView()
        } else if let error = viewModel.error {
            EmptyStateView(
                title: "出错了",
                systemImage: "exclamationmark.triangle",
                description: error
            )
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    stressCard
                    activitySummaryRow
                    vitalsSummaryRow
                    sleepSummaryCard
                    standProgressCard
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - 压力卡片

    private var stressCard: some View {
        let color = stressColor

        return VStack(spacing: 8) {
            Text("当前压力")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let score = viewModel.stressScore {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                        .foregroundStyle(color)
                    Text("分")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(viewModel.stressLevelText)
                    .font(.title3.bold())
                    .foregroundStyle(color)

                // RMSSD detail
                if let rmssd = viewModel.latestRMSSD {
                    Text("RMSSD: \(Int(rmssd)) ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let updated = viewModel.lastStressUpdated {
                    Text("更新于 \(updated, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)

                if !watchConnectivity.isWatchAppInstalled {
                    Text("手表 App 未安装")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("请在 iPhone 的 Watch App 中安装 VitaMind")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if !watchConnectivity.isActivated {
                    Text("请打开手表 App")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("打开一次手表上的 VitaMind 以开始监测")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("正在采集…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("首次压力评估约需 30 秒")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var stressColor: Color {
        guard let score = viewModel.stressScore else { return .secondary }
        switch score {
        case 0...25:  return .green
        case 26...50: return .blue
        case 51...75: return .orange
        default:      return .red
        }
    }

    // MARK: - 活动概览

    private var activitySummaryRow: some View {
        HStack(spacing: 12) {
            MetricCard(
                title: "步数",
                value: "\(viewModel.todaySteps)",
                unit: "步",
                systemImage: "shoeprints.fill",
                color: .green
            )
            MetricCard(
                title: "卡路里",
                value: "\(Int(viewModel.todayCalories))",
                unit: "千卡",
                systemImage: "flame.fill",
                color: .orange
            )
            MetricCard(
                title: "锻炼",
                value: "\(viewModel.todayExerciseMinutes)",
                unit: "分钟",
                systemImage: "figure.run",
                color: .mint
            )
        }
    }

    // MARK: - 生命体征概览

    private var vitalsSummaryRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "心率变异性",
                value: viewModel.latestHRV.map { "\(Int($0))" } ?? "--",
                unit: "毫秒",
                color: .purple
            )
            StatCard(
                title: "血氧",
                value: viewModel.latestSpO2.map { "\(Int($0 * 100))%" } ?? "--",
                unit: "%",
                color: .red
            )
            StatCard(
                title: "呼吸",
                value: viewModel.latestRespiratoryRate.map { "\(Int($0))" } ?? "--",
                unit: "次/分",
                color: .cyan
            )
        }
    }

    // MARK: - 睡眠概览

    private var sleepSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("昨晚睡眠", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", viewModel.lastNightSleepHours))
                    .font(.system(size: 36, weight: .thin, design: .rounded))
                Text("小时")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 站立进度

    private var standProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("站立小时", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(.teal)

            HStack {
                Text("\(viewModel.todayStandHours)/\(viewModel.standGoal)")
                    .font(.title2.bold())
                    .foregroundStyle(.teal)
                Text("小时")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ProgressView(value: Double(viewModel.todayStandHours), total: Double(viewModel.standGoal))
                .tint(.teal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
