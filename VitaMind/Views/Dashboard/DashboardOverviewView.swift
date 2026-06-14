import SwiftUI

struct DashboardOverviewView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(WatchConnectivityManager.self) private var watchConnectivity
    let viewModel: DashboardViewModel
    @State private var isMeasuring = false

    var body: some View {
        Group {
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
                        watchFaceCard
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
        .onChange(of: viewModel.lastStressUpdated) { _, _ in
            isMeasuring = false
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

                // SDNN detail
                if let sdnn = viewModel.latestSDNN {
                    Text("SDNN: \(Int(sdnn)) ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let updated = viewModel.lastStressUpdated {
                    let hoursAgo = Int(Date().timeIntervalSince(updated) / 3600)
                    HStack(spacing: 4) {
                        if Calendar.current.isDateInToday(updated) {
                            Text("测量于 \(updated, style: .time)")
                        } else {
                            Text("测量于 \(updated, style: .date) \(updated, style: .time)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if hoursAgo > 4 {
                        Text("(\(hoursAgo)小时前)")
                            .font(.caption2)
                            .foregroundStyle(.orange)

                        if watchConnectivity.isReachable {
                            if isMeasuring {
                                Label("正在测量…", systemImage: "applewatch.radiowaves.left.and.right")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else {
                                Button {
                                    isMeasuring = true
                                    watchConnectivity.requestMeasurement()
                                    // Auto-reset if no response after 90s
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .seconds(90))
                                        isMeasuring = false
                                    }
                                } label: {
                                    Label("立即测量", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.orange)
                            }
                        }
                    }
                }
            } else {
                Text("--")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)

                if !watchConnectivity.isReachable {
                    Text("手表未连接")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("请确保 Apple Watch 已佩戴并在附近")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if viewModel.watchHKAuthorized == false {
                    Text("手表 HealthKit 未授权")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    if let watchErr = viewModel.watchErrorText {
                        Text(watchErr)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    } else {
                        Text("请打开手表上的 VitaMind App，点击允许授权")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.watchMonitoring == true {
                    Text("正在采集…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("首次压力评估约需 30 秒")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("等待手表上报…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("请打开手表上的 VitaMind App")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 表盘

    private var watchFaceCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Preview
                ZStack {
                    Circle()
                        .fill(.black)
                        .frame(width: 60, height: 60)
                    if let score = viewModel.stressScore {
                        Text("\(score)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(stressColor)
                    } else {
                        Text("--")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(Circle().stroke(stressColor, lineWidth: 2))

                VStack(alignment: .leading, spacing: 4) {
                    Text("添加到 Apple Watch 表盘")
                        .font(.subheadline.bold())
                    Text("长按手表表盘 → 编辑 → 滑动到\n小组件位置 → 选择 VitaMind")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                if let url = URL(string: "itms-watchs://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("打开 Watch App 设置", systemImage: "applewatch")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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
