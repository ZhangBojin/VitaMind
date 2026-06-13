import SwiftUI

struct SleepTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: SleepViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    SleepView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("睡眠")
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
        .onChange(of: healthKitManager.allSamples) { _, _ in
            viewModel?.updateStats()
        }
        .onAppear {
            viewModel = SleepViewModel(healthKitManager: healthKitManager)
        }
    }
}
