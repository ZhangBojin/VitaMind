import SwiftUI

struct SleepView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    let viewModel: SleepViewModel

    var body: some View {
        if !healthKitManager.isAuthorized {
            HealthAuthorizationView()
        } else if let error = viewModel.error {
            EmptyStateView(title: "出错了", systemImage: "exclamationmark.triangle", description: error)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    totalSleepCard
                    stageBreakdown
                    weeklyAverageChartSection
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Total Sleep Card

    private var totalSleepCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.largeTitle)
                .foregroundStyle(.indigo)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", viewModel.totalSleepHours))
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                Text("小时")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text("昨晚")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Stage Breakdown

    @ViewBuilder
    private var stageBreakdown: some View {
        if viewModel.totalSleepHours > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("睡眠阶段")
                    .font(.headline)

                HStack(spacing: 12) {
                    SleepStageCard(label: "深度睡眠", hours: viewModel.deepSleepHours, color: .indigo)
                    SleepStageCard(label: "核心睡眠", hours: viewModel.coreSleepHours, color: .blue)
                }
                HStack(spacing: 12) {
                    SleepStageCard(label: "REM", hours: viewModel.remSleepHours, color: .purple)
                    SleepStageCard(label: "清醒", hours: viewModel.awakeTime, color: .orange)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("暂无睡眠数据")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Apple Watch 会自动记录您的睡眠数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Weekly Average Chart

    @ViewBuilder
    private var weeklyAverageChartSection: some View {
        if !viewModel.weeklyAverages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("每周睡眠")
                    .font(.headline)

                WeeklySleepChart(averages: viewModel.weeklyAverages)

                ForEach(viewModel.weeklyAverages, id: \.label) { day in
                    HStack {
                        Text(day.label)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f 小时", day.hours))
                            .font(.body)
                    }
                    .padding(.vertical, 2)

                    if day.label != viewModel.weeklyAverages.last?.label {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Sleep Stage Card

private struct SleepStageCard: View {
    let label: String
    let hours: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", hours))
                .font(.title2.bold())
                .foregroundStyle(color)
            Text("小时")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Weekly Sleep Chart

private struct WeeklySleepChart: View {
    let averages: [(label: String, hours: Double)]

    var body: some View {
        let maxHours = max(averages.map(\.hours).max() ?? 1, 1)

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(averages, id: \.label) { day in
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", day.hours))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        let height = max(4, CGFloat(day.hours) / CGFloat(maxHours) * (geometry.size.height - 24))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: height)

                        Text(day.label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 120)
    }
}
