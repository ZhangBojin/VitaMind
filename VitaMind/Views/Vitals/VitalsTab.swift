import SwiftUI

struct VitalsTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: VitalsViewModel?
    @State private var isInitialLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel, !isInitialLoading {
                    VitalsView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("生命体征")
        }
        .onChange(of: healthKitManager.allSamples) { _, _ in
            viewModel?.updateStats()
        }
        .onAppear {
            viewModel = VitalsViewModel(healthKitManager: healthKitManager)
            isInitialLoading = false
        }
    }
}
