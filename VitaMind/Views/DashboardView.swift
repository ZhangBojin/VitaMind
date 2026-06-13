import SwiftUI

struct DashboardView: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    dashboardContent(vm)
                } else {
                    ProgressView("Loading health data…")
                }
            }
            .navigationTitle("VitaMind")
            .toolbar {
                if let vm = viewModel {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await vm.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(vm.isLoading)
                    }
                }
            }
        }
        .onChange(of: healthKitManager.heartRateSamples) { _, _ in
            viewModel?.updateStats()
        }
        .onAppear {
            viewModel = DashboardViewModel(healthKitManager: healthKitManager)
            Task { await viewModel?.refresh() }
        }
    }

    // MARK: - Main Dashboard

    @ViewBuilder
    private func dashboardContent(_ vm: DashboardViewModel) -> some View {
        if !healthKitManager.isAuthorized {
            authorizationPrompt
        } else if let error = vm.error {
            errorView(error)
        } else {
            ScrollView {
                VStack(spacing: 24) {
                    currentHeartRateCard(vm)
                    statsRow(vm)
                    trendSection(vm)
                }
                .padding()
            }
            .refreshable {
                await vm.refresh()
            }
        }
    }

    // MARK: - Current Heart Rate Card

    private func currentHeartRateCard(_ vm: DashboardViewModel) -> some View {
        VStack(spacing: 8) {
            Text("Current Heart Rate")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let bpm = vm.latestHeartRate {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(bpm))")
                        .font(.system(size: 72, weight: .thin, design: .rounded))
                    Text("BPM")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)
            } else {
                Text("--")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .foregroundStyle(.tertiary)
                Text("No data yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Stats Row

    private func statsRow(_ vm: DashboardViewModel) -> some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Avg",
                value: vm.averageHeartRate.map { "\(Int($0))" } ?? "--",
                unit: "BPM",
                color: .blue
            )
            StatCard(
                title: "Min",
                value: vm.minHeartRate.map { "\(Int($0))" } ?? "--",
                unit: "BPM",
                color: .green
            )
            StatCard(
                title: "Max",
                value: vm.maxHeartRate.map { "\(Int($0))" } ?? "--",
                unit: "BPM",
                color: .orange
            )
        }
    }

    // MARK: - Trend Section

    @ViewBuilder
    private func trendSection(_ vm: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Readings")
                .font(.headline)

            if vm.recentSamples.isEmpty {
                Text("No readings available. Wear your Apple Watch or ensure HealthKit has heart rate data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Sparkline-style bar chart
                HeartRateChart(samples: vm.recentSamples)

                // Sample list
                ForEach(vm.recentSamples.prefix(20)) { sample in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(sample.bpm)) BPM")
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

                    if sample.id != vm.recentSamples.prefix(20).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - States

    private var authorizationPrompt: some View {
        ContentUnavailableView(
            "Health Access Required",
            systemImage: "heart.slash",
            description: Text("VitaMind needs access to your heart rate data in Apple Health. Open the Health app to grant permission.")
        )
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView(
            "Something went wrong",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Heart Rate Chart (Simple Bar Sparkline)

private struct HeartRateChart: View {
    let samples: [HeartRateSample]

    var body: some View {
        let sorted = samples.sorted { $0.date < $1.date }
        let maxBPM = sorted.map(\.bpm).max() ?? 100
        let minBPM = sorted.map(\.bpm).min() ?? 40
        let range = max(maxBPM - minBPM, 1)

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(sorted) { sample in
                    let height = max(4, (sample.bpm - minBPM) / range * geometry.size.height)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(2, (geometry.size.width / CGFloat(max(sorted.count, 1))) - 2))
                        .frame(height: height)
                }
            }
        }
        .frame(height: 80)
    }
}

#Preview {
    DashboardView()
        .environment(HealthKitManager())
}
