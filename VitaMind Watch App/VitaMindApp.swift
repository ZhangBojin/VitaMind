//
//  VitaMindApp.swift
//  VitaMind Watch App
//
//  Created by 丑丑 on 2026/6/7.
//

import SwiftUI

@main
struct VitaMind_Watch_AppApp: App {
    private let healthKitManager = WatchHealthKitManager()
    private let connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(healthKitManager)
                .environment(connectivityManager)
                .task {
                    // Forward new heart rate samples from HealthKit to the phone.
                    healthKitManager.onNewHeartRate = { sample in
                        connectivityManager.sendHeartRate(sample)
                    }
                }
        }
    }
}
