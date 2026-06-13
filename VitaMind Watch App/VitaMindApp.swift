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

                    // Request authorization and start observing once.
                    await healthKitManager.requestAuthorization()
                    healthKitManager.startObservingAll()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                healthKitManager.stopObserving()
            } else if newPhase == .active {
                healthKitManager.startObservingAll()
            }
        }
    }
}
