//
//  ContentView.swift
//  VitaMind
//
//  Created by 丑丑 on 2026/6/7.
//

import SwiftUI

struct ContentView: View {
    @Environment(HealthKitManager.self) private var healthKitManager

    var body: some View {
        TabView {
            DashboardTab()
                .tabItem {
                    Label("概览", systemImage: "house.fill")
                }

            HeartTab()
                .tabItem {
                    Label("心脏", systemImage: "heart.fill")
                }

            ActivityTab()
                .tabItem {
                    Label("活动", systemImage: "flame.fill")
                }

            SleepTab()
                .tabItem {
                    Label("睡眠", systemImage: "moon.zzz.fill")
                }

            VitalsTab()
                .tabItem {
                    Label("生命体征", systemImage: "lungs.fill")
                }
        }
        .tint(.red)
    }
}

#Preview {
    ContentView()
        .environment(HealthKitManager())
}
