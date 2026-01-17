//
//  EarthLord_day7App.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI
import GoogleSignIn
import UIKit

@main
struct EarthLord_day7App: App {
    @StateObject private var authManager = AuthManager()
    private var languageManager = LanguageManager.shared
    private var locationManager = LocationManager.shared

    /// Google Client ID
    private let googleClientID = "15540158218-9g4hjhe8k5t7beust04bf11h4pad6thq.apps.googleusercontent.com"

    init() {
        // 配置 Google Sign-In
        print("🔵 [App] 正在配置 Google Sign-In...")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
        print("✅ [App] Google Sign-In 配置完成")

        // App生命周期监听 - 玩家位置管理
        setupAppLifecycleObservers()
    }

    /// 设置App生命周期监听器
    private func setupAppLifecycleObservers() {
        // App进入后台 - 标记玩家离线
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔵 [App] 进入后台，标记玩家离线")
            Task {
                await PlayerLocationManager.shared.setOffline()
            }
        }

        // App回到前台 - 上报玩家位置
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("🔵 [App] 回到前台，上报玩家位置")
            Task {
                await PlayerLocationManager.shared.setOnlineAndReport()
            }
        }

        print("✅ [App] 生命周期监听器设置完成")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(languageManager)
                .environmentObject(locationManager)
                .onOpenURL { url in
                    // 处理 Google Sign-In 回调 URL
                    print("🔵 [App] 收到 URL 回调: \(url)")
                    if GIDSignIn.sharedInstance.handle(url) {
                        print("✅ [App] Google Sign-In 成功处理 URL")
                    } else {
                        print("⚠️ [App] URL 未被 Google Sign-In 处理")
                    }
                }
        }
    }
}
