import SwiftUI

struct VitalsView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    let viewModel: VitalsViewModel

    var body: some View {
        if !healthKitManager.isAuthorized {
            HealthAuthorizationView()
        } else if let error = viewModel.error {
            EmptyStateView(title: "出错了", systemImage: "exclamationmark.triangle", description: error)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    spO2Card
                    respiratoryRateCard
                    spO2ChartSection
                    respiratoryRateChartSection
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Blood Oxygen Card

    private var spO2Card: some View {
        VStack(spacing: 8) {
            Image(systemName: "lungs.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)

            if let spo2 = viewModel.latestSpO2 {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(spo2 * 100))")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                    Text("%")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text("血氧饱和度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // 平均/最高
                HStack(spacing: 16) {
                    if let avg = viewModel.averageSpO2 {
                        Label("\(Int(avg * 100))% 平均", systemImage: "target")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    if let max = viewModel.maxSpO2 {
                        Label("\(Int(max * 100))% 最高", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            } else {
                Text("--%")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("暂无血氧数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Respiratory Rate Card

    private var respiratoryRateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.largeTitle)
                .foregroundStyle(.cyan)

            if let rate = viewModel.latestRespiratoryRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(rate))")
                        .font(.system(size: 56, weight: .thin, design: .rounded))
                    Text("次/分")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text("呼吸频率")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let avg = viewModel.averageRespiratoryRate {
                    Text("平均: \(Int(avg)) 次/分")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("-- 次/分")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("暂无呼吸频率数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - SpO2 Chart

    @ViewBuilder
    private var spO2ChartSection: some View {
        if !viewModel.bloodOxygenSamples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("血氧趋势")
                    .font(.headline)

                // Convert fractional values to percentage for display
                let displaySamples = viewModel.bloodOxygenSamples.map { sample in
                    HealthSample(
                        id: sample.id,
                        type: sample.type,
                        value: sample.value * 100,
                        unit: "%",
                        date: sample.date,
                        source: sample.source,
                        metadata: sample.metadata
                    )
                }

                HealthChart(
                    samples: Array(displaySamples.prefix(30)),
                    color: .red,
                    secondaryColor: .pink
                )

                ForEach(Array(viewModel.bloodOxygenSamples.prefix(10))) { sample in
                    HStack {
                        Text("\(Int(sample.value * 100))%")
                            .font(.body)
                        Text(sample.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(sample.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Respiratory Rate Chart

    @ViewBuilder
    private var respiratoryRateChartSection: some View {
        if !viewModel.respiratoryRateSamples.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("呼吸频率趋势")
                    .font(.headline)

                HealthChart(
                    samples: Array(viewModel.respiratoryRateSamples.prefix(30)),
                    color: .cyan,
                    secondaryColor: .blue
                )

                ForEach(Array(viewModel.respiratoryRateSamples.prefix(10))) { sample in
                    HStack {
                        Text("\(Int(sample.value)) 次/分")
                            .font(.body)
                        Text(sample.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(sample.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
