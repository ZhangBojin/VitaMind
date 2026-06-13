import SwiftUI

struct DashboardTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: DashboardViewModel?
    @State private var isInitialLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel, !isInitialLoading {
                    DashboardOverviewView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("VitaMind")
            .toolbar {
                if let vm = viewModel, !isInitialLoading {
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
        .onChange(of: healthKitManager.allSamples) { _, _ in
            viewModel?.updateStats()
        }
        .onChange(of: healthKitManager.lastStressUpdated) { _, _ in
            viewModel?.updateStats()
        }
        .onChange(of: healthKitManager.watchStatus.lastReportTime) { _, _ in
            viewModel?.updateStats()
        }
        .onAppear {
            viewModel = DashboardViewModel(healthKitManager: healthKitManager)
            Task {
                await viewModel?.refresh()
                isInitialLoading = false
            }
        }
    }
}
