//
//  ContentView.swift
//  VitaMind
//
//  Created by 丑丑 on 2026/6/7.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        DashboardView()
    }
}

#Preview {
    ContentView()
        .environment(HealthKitManager())
}
