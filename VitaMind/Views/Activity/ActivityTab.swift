import SwiftUI

struct ActivityTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: ActivityViewModel?
    @State private var isInitialLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel, !isInitialLoading {
                    ActivityView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("活动")
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
        .onAppear {
            viewModel = ActivityViewModel(healthKitManager: healthKitManager)
            isInitialLoading = false
        }
    }
}
