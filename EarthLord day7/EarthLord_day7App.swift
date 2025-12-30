//
//  EarthLord_day7App.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI

@main
struct EarthLord_day7App: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }
}
