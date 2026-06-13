//
//  VitaMindApp.swift
//  VitaMind Watch App
//
//  Created by 丑丑 on 2026/6/7.
//

import SwiftUI

@main
struct VitaMind_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var healthKitManager = WatchHealthKitManager()
    @State private var connectivityManager = WatchConnectivityManager()
    @State private var stressMonitor = StressMonitor()
    @State private var didSetup = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(connectivityManager)
                .task {
                    guard !didSetup else { return }
                    didSetup = true

                    // Wire callbacks.
                    healthKitManager.onNewSample = { sample in
                        connectivityManager.sendSample(sample)
                    }

                    stressMonitor.onStressResult = { result in
                        connectivityManager.sendStressResult(
                            score: result.score,
                            sdnn: result.sdnn,
                            level: result.level.rawValue,
                            timestamp: result.timestamp
                        )
                        reportStatus()
                    }

                    // Handle measurement request from iPhone.
                    connectivityManager.onStartMeasurement = {
                        Task {
                            await stressMonitor.forceMeasurement()
                        }
                    }

                    // Authorize and start.
                    await healthKitManager.requestAuthorization()
                    if healthKitManager.isAuthorized {
                        healthKitManager.startObservingAll()
                        stressMonitor.start()
                    } else {
                        reportStatus()
                        scheduleStatusRetries()
                        return
                    }

                    // WCSession may not be ready yet — retry status reports.
                    reportStatus()
                    scheduleStatusRetries()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                healthKitManager.stopObserving()
            } else if newPhase == .active {
                healthKitManager.startObservingAll()
                if healthKitManager.isAuthorized {
                    stressMonitor.start()
                }
                reportStatus()
                scheduleStatusRetries()
            }
        }
    }

    // MARK: - Status reporting

    private func reportStatus() {
        connectivityManager.sendWatchStatus(
            hkAuthorized: healthKitManager.isAuthorized,
            monitoring: stressMonitor.isSampling,
            errorText: healthKitManager.error ?? stressMonitor.error
        )
    }

    /// Re-report status at increasing intervals to handle WCSession not yet activated.
    private func scheduleStatusRetries() {
        for delay in [1.0, 3.0, 10.0, 30.0] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                reportStatus()
            }
        }
    }
}
