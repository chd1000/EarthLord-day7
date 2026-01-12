//
//  MapTabView.swift
//  EarthLord day7
//
//  地图页面
//  显示苹果地图、用户位置、末世滤镜效果、路径追踪、闭环检测、速度警告
//

import SwiftUI
import MapKit
import Supabase

struct MapTabView: View {

    // MARK: - 环境对象
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var authManager: AuthManager

    // MARK: - 状态管理
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var territoryManager = TerritoryManager.shared

    /// 已加载的领地列表
    @State private var territories: [Territory] = []

    /// 用户位置坐标
    @State private var userLocation: CLLocationCoordinate2D?

    /// 是否已完成首次定位
    @State private var hasLocatedUser: Bool = false

    /// 是否需要重新居中
    @State private var shouldRecenter: Bool = false

    /// 是否显示验证结果横幅
    @State private var showValidationBanner: Bool = false

    /// 圈地开始时间
    @State private var trackingStartTime: Date? = nil

    /// 是否正在上传
    @State private var isUploading: Bool = false

    /// 上传成功提示
    @State private var showUploadSuccess: Bool = false

    /// 上传失败提示
    @State private var showUploadError: Bool = false
    @State private var uploadErrorMessage: String = ""

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

            // 速度警告横幅（在顶部显示）
            VStack {
                if let warning = locationManager.speedWarning {
                    speedWarningBanner(warning)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.3), value: locationManager.speedWarning)

            // 验证结果横幅（闭环后根据验证结果显示成功/失败）
            if showValidationBanner {
                validationResultBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 控制按钮区域
            VStack {
                Spacer()

                // 确认登记按钮（验证通过时显示）
                if locationManager.territoryValidationPassed && !isUploading {
                    confirmButton
                        .padding(.bottom, 12)
                }

                // 上传中指示器
                if isUploading {
                    uploadingIndicator
                        .padding(.bottom, 12)
                }

                HStack(alignment: .bottom) {
                    // 圈地按钮（左下角）
                    trackingButton
                        .padding(.leading, 16)

                    Spacer()

                    // 定位按钮（右下角）
                    locateButton
                        .padding(.trailing, 16)
                }
                .padding(.bottom, 16)
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
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                // 闭环后延迟一点点，等待验证结果
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showValidationBanner = true
                    }
                    // 3 秒后自动隐藏
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showValidationBanner = false
                        }
                    }
                }
            }
        }
        // 上传失败提示
        .alert("登记失败", isPresented: $showUploadError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(uploadErrorMessage)
        }
    }

    // MARK: - 地图视图

    private var mapView: some View {
        MapViewRepresentable(
            userLocation: $userLocation,
            hasLocatedUser: $hasLocatedUser,
            shouldRecenter: $shouldRecenter,
            trackingPath: $locationManager.pathCoordinates,
            pathUpdateVersion: locationManager.pathUpdateVersion,
            isTracking: locationManager.isTracking,
            isPathClosed: locationManager.isPathClosed,
            territories: territories,
            currentUserId: authManager.currentUser?.id.uuidString
        )
        .ignoresSafeArea(edges: .top)  // 只忽略顶部安全区域，保留底部 Tab 栏
    }

    // MARK: - 速度警告横幅

    private func speedWarningBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            // 警告图标
            Image(systemName: locationManager.isTracking ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 18))

            // 警告文字
            Text(message)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(locationManager.isTracking ? ApocalypseTheme.warning : ApocalypseTheme.danger)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.top, 60)  // 留出状态栏空间
    }

    // MARK: - 验证结果横幅

    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                // 图标（根据验证结果显示不同图标）
                Image(systemName: locationManager.territoryValidationPassed
                      ? "checkmark.circle.fill"
                      : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)

                // 文字内容
                if locationManager.territoryValidationPassed {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageManager.localizedString("圈地成功"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageManager.localizedString("圈地失败"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text(locationManager.territoryValidationError ?? "验证失败")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(locationManager.territoryValidationPassed ? Color.green : Color.red)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 100)  // 留出按钮空间
        }
    }

    // MARK: - 圈地按钮

    private var trackingButton: some View {
        Button {
            toggleTracking()
        } label: {
            HStack(spacing: 8) {
                // 图标
                Image(systemName: buttonIcon)
                    .font(.system(size: 16, weight: .semibold))

                // 文字
                if locationManager.isTracking {
                    Text(languageManager.localizedString("停止圈地"))
                        .font(.system(size: 14, weight: .semibold))

                    // 显示当前点数
                    Text("(\(locationManager.pathPointCount))")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.8)
                } else {
                    Text(languageManager.localizedString("开始圈地"))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(buttonBackgroundColor)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            )
        }
        .disabled(!locationManager.isAuthorized)
        .opacity(locationManager.isAuthorized ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: locationManager.isTracking)
        .animation(.easeInOut(duration: 0.3), value: locationManager.isPathClosed)
    }

    /// 按钮图标
    private var buttonIcon: String {
        if locationManager.isPathClosed {
            return "checkmark.circle.fill"
        } else if locationManager.isTracking {
            return "stop.fill"
        } else {
            return "flag.fill"
        }
    }

    /// 按钮背景颜色
    private var buttonBackgroundColor: Color {
        if locationManager.isPathClosed {
            return Color.green
        } else if locationManager.isTracking {
            return ApocalypseTheme.danger
        } else {
            return ApocalypseTheme.primary
        }
    }

    // MARK: - 确认登记按钮

    private var confirmButton: some View {
        Button {
            Task {
                await uploadCurrentTerritory()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text(languageManager.localizedString("确认登记领地"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            )
        }
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: locationManager.territoryValidationPassed)
    }

    // MARK: - 上传中指示器

    private var uploadingIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)

            Text(languageManager.localizedString("正在登记..."))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(ApocalypseTheme.primary.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        )
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

        // 加载领地数据
        Task {
            await loadTerritories()
        }
    }

    /// 加载领地数据
    private func loadTerritories() async {
        await territoryManager.loadAllTerritories()
        territories = territoryManager.territories
        TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
    }

    /// 切换圈地追踪状态
    private func toggleTracking() {
        if locationManager.isTracking {
            // 停止追踪（保留轨迹显示，不清除数据）
            locationManager.stopPathTracking()
            print("🛑 用户停止圈地")
        } else {
            // 记录开始时间
            trackingStartTime = Date()
            // 开始追踪
            locationManager.startPathTracking()
            print("🚶 用户开始圈地")
        }
    }

    /// 上传当前领地
    private func uploadCurrentTerritory() async {
        // 再次检查验证状态
        guard locationManager.territoryValidationPassed else {
            print("❌ 领地验证未通过，无法上传")
            TerritoryLogger.shared.log("上传被阻止：领地验证未通过", type: .error)
            return
        }

        // 防止重复点击
        guard !isUploading else { return }

        isUploading = true
        print("📤 开始上传领地...")

        let success = await territoryManager.uploadTerritory(
            pathCoordinates: locationManager.pathCoordinates,
            area: locationManager.calculatedArea,
            startTime: trackingStartTime,
            endTime: Date()
        )

        isUploading = false

        if success {
            print("✅ 领地上传成功！")

            // 显示成功提示
            showUploadSuccess = true

            // 上传成功后停止追踪并清除数据
            locationManager.stopPathTracking(clearData: true)
            trackingStartTime = nil

            // 刷新领地列表（在地图上显示新领地）
            await loadTerritories()

            // 3秒后隐藏成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showUploadSuccess = false
            }
        } else {
            print("❌ 领地上传失败: \(territoryManager.errorMessage ?? "未知错误")")
            // 显示错误提示
            uploadErrorMessage = territoryManager.errorMessage ?? "未知错误"
            showUploadError = true
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
        .environmentObject(AuthManager())
}
