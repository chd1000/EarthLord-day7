//
//  MapTabView.swift
//  EarthLord day7
//
//  地图页面
//  显示苹果地图、用户位置、末世滤镜效果
//

import SwiftUI
import MapKit

struct MapTabView: View {

    // MARK: - 环境对象
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - 状态管理
    @StateObject private var locationManager = LocationManager.shared

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser: Bool = false

    /// 是否需要重新居中
    @State private var shouldRecenter: Bool = false

    var body: some View {
        ZStack {
            // 地图视图
            mapView

            // 顶部渐变遮罩（让标题更清晰）
            VStack {
                LinearGradient(
                    colors: [
                        ApocalypseTheme.background.opacity(0.8),
                        ApocalypseTheme.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)

                Spacer()
            }
            .ignoresSafeArea(edges: .top)  // 只忽略顶部

            // 控制按钮
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    // 定位按钮
                    locateButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)  // 调整底部间距，Tab 栏现在可见
                }
            }

            // 权限被拒绝时显示提示
            if locationManager.isDenied {
                deniedPermissionView
            }

            // 加载指示器
            if !hasLocatedUser && locationManager.isAuthorized {
                loadingOverlay
            }
        }
        .onAppear {
            handleOnAppear()
        }
    }

    // MARK: - 地图视图

    private var mapView: some View {
        MapViewRepresentable(
            userLocation: $userLocation,
            hasLocatedUser: $hasLocatedUser,
            shouldRecenter: $shouldRecenter
        )
        .ignoresSafeArea(edges: .top)  // 只忽略顶部安全区域，保留底部 Tab 栏
    }

    // MARK: - 定位按钮

    private var locateButton: some View {
        Button {
            recenterToUser()
        } label: {
            ZStack {
                // 按钮背景
                Circle()
                    .fill(ApocalypseTheme.cardBackground.opacity(0.9))
                    .frame(width: 50, height: 50)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

                // 定位图标
                Image(systemName: locationManager.isAuthorized ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 22))
                    .foregroundColor(locationManager.isAuthorized ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            }
        }
        .disabled(!locationManager.isAuthorized)
    }

    // MARK: - 权限被拒绝提示

    private var deniedPermissionView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                // 图标
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(ApocalypseTheme.warning)

                // 标题
                Text(languageManager.localizedString("定位权限被拒绝"))
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 描述
                Text(languageManager.localizedString("请在系统设置中开启定位权限，以便在末日世界中显示您的位置"))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // 前往设置按钮
                Button {
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text(languageManager.localizedString("前往设置"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
            }
            .padding(24)
            .background(ApocalypseTheme.cardBackground.opacity(0.95))
            .cornerRadius(20)
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color.black.opacity(0.5))
        .ignoresSafeArea()
    }

    // MARK: - 加载指示器

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                .scaleEffect(1.5)

            Text(languageManager.localizedString("正在获取位置..."))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(30)
        .background(ApocalypseTheme.cardBackground.opacity(0.9))
        .cornerRadius(16)
    }

    // MARK: - 方法

    /// 页面出现时的处理
    private func handleOnAppear() {
        print("🗺️ MapTabView 出现")

        // 检查授权状态
        if locationManager.isNotDetermined {
            // 首次使用，请求权限
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            // 已授权，开始定位
            locationManager.startUpdatingLocation()
        }
    }

    /// 重新居中到用户位置
    private func recenterToUser() {
        guard locationManager.isAuthorized else {
            // 未授权时打开设置
            if locationManager.isDenied {
                openSettings()
            }
            return
        }

        shouldRecenter = true
        print("📍 重新居中到用户位置")
    }

    /// 打开系统设置
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

#Preview {
    MapTabView()
        .environmentObject(LanguageManager.shared)
}
