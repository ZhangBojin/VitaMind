import SwiftUI

struct ActivityView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    let viewModel: ActivityViewModel

    var body: some View {
        if !healthKitManager.isAuthorized {
            HealthAuthorizationView()
        } else if let error = viewModel.error {
            EmptyStateView(title: "出错了", systemImage: "exclamationmark.triangle", description: error)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    stepsCard
                    energyExerciseRow
                    standProgressCard
                    stepHistoryChartSection
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Steps Counter

    private var stepsCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "shoeprints.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("\(viewModel.todaySteps)")
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)

            Text("步")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 目标进度
            let progress = min(Double(viewModel.todaySteps) / Double(viewModel.stepGoal), 1.0)
            ProgressView(value: progress)
                .tint(.green)
                .padding(.horizontal, 24)

            Text("目标: \(viewModel.stepGoal) 步")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Energy & Exercise

    private var energyExerciseRow: some View {
        HStack(spacing: 12) {
            MetricCard(
                title: "活动能量",
                value: "\(Int(viewModel.activeCalories))",
                unit: "千卡",
                systemImage: "flame.fill",
                color: .orange
            )
            MetricCard(
                title: "锻炼",
                value: "\(viewModel.exerciseMinutes)",
                unit: "分钟",
                systemImage: "figure.run",
                color: .mint
            )
        }
    }

    // MARK: - Stand Hours

    private var standProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("站立小时", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(.teal)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.standHours)")
                        .font(.system(size: 36, weight: .thin, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("共 \(viewModel.standGoal) 小时")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(value: Double(viewModel.standHours), total: Double(viewModel.standGoal))
                .tint(.teal)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Step History Chart

    @ViewBuilder
    private var stepHistoryChartSection: some View {
        if !viewModel.stepHistory.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("近7天步数")
                    .font(.headline)

                // Simple bar chart using HealthChart pattern
                StepBarChart(history: viewModel.stepHistory)

                // Daily breakdown
                ForEach(viewModel.stepHistory, id: \.label) { day in
                    HStack {
                        Text(day.label)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(day.steps) 步")
                            .font(.body)
                    }
                    .padding(.vertical, 2)

                    if day.label != viewModel.stepHistory.last?.label {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Step Bar Chart

private struct StepBarChart: View {
    let history: [(label: String, steps: Int)]

    var body: some View {
        let maxSteps = max(history.map(\.steps).max() ?? 1, 1)

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(history, id: \.label) { day in
                    VStack(spacing: 2) {
                        let height = max(4, CGFloat(day.steps) / CGFloat(maxSteps) * (geometry.size.height - 20))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.green, .mint],
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
