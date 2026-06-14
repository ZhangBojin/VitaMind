import SwiftUI

struct SleepTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: SleepViewModel?
    @State private var isInitialLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel, !isInitialLoading {
                    SleepView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("睡眠")
        }
        .onChange(of: healthKitManager.allSamples) { _, _ in
            viewModel?.updateStats()
        }
        .onAppear {
            viewModel = SleepViewModel(healthKitManager: healthKitManager)
            isInitialLoading = false
        }
    }
}
