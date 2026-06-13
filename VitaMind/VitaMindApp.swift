//
//  VitaMindApp.swift
//  VitaMind
//
//  Created by 丑丑 on 2026/6/7.
//

import SwiftUI

@main
struct VitaMindApp: App {
    @State private var healthKitManager = HealthKitManager()
    @State private var watchConnectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(watchConnectivityManager)
                .task {
                    // Wire watch data into the HealthKit pipeline.
                    watchConnectivityManager.onSampleReceived = { sample in
                        healthKitManager.ingestSingleSample(sample)
                    }
                    // Wire stress results from watch.
                    watchConnectivityManager.onStressResultReceived = { result in
                        healthKitManager.ingestStressResult(
                            score: result.score,
                            rmssd: result.rmssd,
                            level: result.level,
                            timestamp: result.timestamp
                        )
                    }
                    // Wire watch diagnostic status.
                    watchConnectivityManager.onWatchStatusReceived = { status in
                        healthKitManager.updateWatchStatus(
                            hkAuthorized: status.healthKitAuthorized,
                            monitoring: status.stressMonitoring,
                            errorText: status.errorText,
                            timestamp: status.timestamp
                        )
                    }

                    // Request HealthKit access and begin observing all types.
                    await healthKitManager.requestAuthorization()
                    if healthKitManager.isAuthorized {
                        await healthKitManager.fetchAllSamples(
                            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        )
                        healthKitManager.startAllObservers()
                    }
                }
        }
    }
}
