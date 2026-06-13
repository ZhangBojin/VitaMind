import SwiftUI

struct VitalsTab: View {
    @Environment(HealthKitManager.self) private var healthKitManager
    @State private var viewModel: VitalsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    VitalsView(viewModel: vm)
                } else {
                    ProgressView("加载中…")
                }
            }
            .navigationTitle("生命体征")
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
            viewModel = VitalsViewModel(healthKitManager: healthKitManager)
        }
    }
}
