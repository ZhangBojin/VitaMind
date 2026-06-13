import SwiftUI

struct HeartView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    let viewModel: HeartViewModel

    var body: some View {
        if !healthKitManager.isAuthorized {
            HealthAuthorizationView()
        } else if let error = viewModel.error {
            EmptyStateView(title: "出错了", systemImage: "exclamationmark.triangle", description: error)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    currentHeartRateCard
                    hrvCard
                    restingWalkingRow
                    heartRateChartSection
                    hrvChartSection
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Current Heart Rate

    private var currentHeartRateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
                .symbolEffect(.pulse, options: .repeating)

            if let bpm = viewModel.currentHeartRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(bpm))")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                    Text("次/分")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            // 最低/最高
            if let min = viewModel.minHeartRate, let max = viewModel.maxHeartRate {
                HStack(spacing: 16) {
                    Label("\(Int(min)) 最低", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Label("\(Int(max)) 最高", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - HRV Card

    private var hrvCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title)
                .foregroundStyle(.purple)

            if let hrv = viewModel.averageHRV {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(hrv))")
                        .font(.system(size: 48, weight: .thin, design: .rounded))
                    Text("毫秒")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text("平均心率变异性")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("-- 毫秒")
                    .font(.system(size: 48, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("暂无心率变异性数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Resting & Walking

    private var restingWalkingRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "静息心率",
                value: viewModel.restingHeartRate.map { "\(Int($0))" } ?? "--",
                unit: "次/分",
                color: .pink
            )
            StatCard(
                title: "步行平均",
                value: viewModel.walkingHeartRateAvg.map { "\(Int($0))" } ?? "--",
                unit: "次/分",
                color: .orange
            )
        }
    }

    // MARK: - Heart Rate Chart

    @ViewBuilder
    private var heartRateChartSection: some View {
        if !viewModel.heartRateSamples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("心率趋势")
                    .font(.headline)

                HealthChart(
                    samples: Array(viewModel.heartRateSamples.prefix(50)),
                    color: .red,
                    secondaryColor: .orange
                )

                // Recent readings
                ForEach(Array(viewModel.heartRateSamples.prefix(15))) { sample in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(sample.value)) 次/分")
                                .font(.body)
                            Text(sample.source)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(sample.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    if sample.id != viewModel.heartRateSamples.prefix(15).last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - HRV Chart

    @ViewBuilder
    private var hrvChartSection: some View {
        if !viewModel.hrvSamples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("心率变异性趋势")
                    .font(.headline)

                HealthChart(
                    samples: Array(viewModel.hrvSamples.prefix(30)),
                    color: .purple
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
