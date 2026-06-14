import SwiftUI

struct HeartTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: HeartViewModel?
    @State private var isInitialLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel, !isInitialLoading {
                    HeartView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("心脏")
        }
        .onChange(of: healthKitManager.allSamples) { _, _ in
            viewModel?.updateStats()
        }
        .onAppear {
            viewModel = HeartViewModel(healthKitManager: healthKitManager)
            isInitialLoading = false
        }
    }
}
