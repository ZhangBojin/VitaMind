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
                    watchConnectivityManager.onHeartRateReceived = { sample in
                        healthKitManager.ingestSamples([sample])
                    }

                    // Request HealthKit access and begin observing.
                    await healthKitManager.requestAuthorization()
                    if healthKitManager.isAuthorized {
                        await healthKitManager.fetchHeartRateSamples(
                            from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        )
                        healthKitManager.startHeartRateObserver()
                    }
                }
        }
    }
}
