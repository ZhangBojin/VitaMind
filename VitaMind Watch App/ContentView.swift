//
//  ContentView.swift
//  VitaMind Watch App
//
//  Created by 丑丑 on 2026/6/7.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HeartRateView()
            HRVWatchView()
            StepsWatchView()
        }
        #if os(watchOS)
        .tabViewStyle(.verticalPage)
        #endif
    }
}

#Preview {
    ContentView()
        .environment(WatchHealthKitManager())
        .environment(WatchConnectivityManager())
}
