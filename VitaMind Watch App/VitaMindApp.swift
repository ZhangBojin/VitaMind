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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(connectivityManager)
                .task {
                    // Forward new health samples from HealthKit to the phone.
                    healthKitManager.onNewSample = { sample in
                        connectivityManager.sendSample(sample)
                    }

                    // Forward stress results to the phone.
                    stressMonitor.onStressResult = { result in
                        connectivityManager.sendStressResult(
                            score: result.score,
                            rmssd: result.rmssd,
                            level: result.level.rawValue,
                            timestamp: result.timestamp
                        )
                    }

                    // Request authorization, then start health + stress monitoring.
                    await healthKitManager.requestAuthorization()
                    healthKitManager.startObservingAll()
                    stressMonitor.start()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                // Stop regular HealthKit observers, but keep the stress monitor
                // running — HKWorkoutSession continues in background on watchOS.
                healthKitManager.stopObserving()
            } else if newPhase == .active {
                healthKitManager.startObservingAll()
                // stressMonitor.start() is safe to call multiple times —
                // it skips if already running.
                stressMonitor.start()
            }
        }
    }
}
