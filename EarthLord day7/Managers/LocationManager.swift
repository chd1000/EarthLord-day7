//
//  LocationManager.swift
//  EarthLord day7
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误、路径追踪
//

import Foundation
import CoreLocation
import Combine  // @Published 需要此框架

/// GPS 定位管理器
class LocationManager: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = LocationManager()

    // MARK: - 核心定位管理器
    private let locationManager = CLLocationManager()

    // MARK: - 发布的状态（基础定位）

    /// 用户当前位置坐标
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus

    /// 定位错误信息
    @Published var locationError: String?

    /// 是否正在定位
    @Published var isUpdatingLocation: Bool = false

    // MARK: - 发布的状态（路径追踪）

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（用于触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合（Day16 会用到）
    @Published var isPathClosed: Bool = false

    // MARK: - 私有属性（路径追踪）

    /// 当前位置（供 Timer 采点使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 最小移动距离（米）- 移动超过此距离才记录新点
    private let minimumDistance: CLLocationDistance = 10.0

    // MARK: - 计算属性

    /// 是否已获得定位授权
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// 是否被用户拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 是否尚未决定（首次请求）
    var isNotDetermined: Bool {
        authorizationStatus == .notDetermined
    }

    /// 路径点数量
    var pathPointCount: Int {
        pathCoordinates.count
    }

    // MARK: - 初始化

    override init() {
        // 获取当前授权状态
        self.authorizationStatus = locationManager.authorizationStatus

        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 5  // 移动5米就更新位置（追踪时需要更频繁）

        print("📍 LocationManager 初始化完成，当前授权状态: \(authorizationStatusText)")
    }

    // MARK: - 公开方法（基础定位）

    /// 请求定位权限
    func requestPermission() {
        print("📍 请求定位权限...")
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            print("⚠️ 未获得定位授权，无法开始定位")
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        print("📍 开始更新位置...")
        isUpdatingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        print("📍 停止更新位置")
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// 请求单次位置更新
    func requestLocation() {
        guard isAuthorized else {
            print("⚠️ 未获得定位授权，无法获取位置")
            if isNotDetermined {
                requestPermission()
            }
            return
        }

        print("📍 请求单次位置...")
        locationError = nil
        locationManager.requestLocation()
    }

    // MARK: - 公开方法（路径追踪）

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            print("⚠️ 未获得定位授权，无法开始路径追踪")
            return
        }

        print("🚶 开始路径追踪...")

        // 清除之前的路径
        clearPath()

        // 标记正在追踪
        isTracking = true
        isPathClosed = false

        // 确保定位已开启
        if !isUpdatingLocation {
            startUpdatingLocation()
        }

        // 如果当前有位置，立即记录第一个点
        if let location = currentLocation {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            print("📍 记录起始点: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("⏱️ 采点定时器已启动，间隔: \(trackingInterval)秒")
    }

    /// 停止路径追踪
    func stopPathTracking() {
        print("🛑 停止路径追踪，共记录 \(pathCoordinates.count) 个点")

        // 停止定时器
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        // 标记停止追踪
        isTracking = false

        // 注意：不清除路径，保留轨迹显示
    }

    /// 清除路径
    func clearPath() {
        print("🗑️ 清除路径")
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
    }

    // MARK: - 私有方法（路径追踪）

    /// 定时器回调 - 判断是否记录新点
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else {
            print("⚠️ 当前位置为空，跳过采点")
            return
        }

        // 检查是否需要记录新点
        if let lastCoordinate = pathCoordinates.last {
            // 计算与上一个点的距离
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 只有移动超过最小距离才记录
            if distance < minimumDistance {
                print("📍 移动距离不足 (\(String(format: "%.1f", distance))m < \(minimumDistance)m)，跳过采点")
                return
            }

            print("📍 移动距离: \(String(format: "%.1f", distance))m，记录新点")
        }

        // 记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        print("📍 记录第 \(pathCoordinates.count) 个点: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
    }

    // MARK: - 私有方法（其他）

    /// 授权状态文本描述
    private var authorizationStatusText: String {
        switch authorizationStatus {
        case .notDetermined: return "未决定"
        case .restricted: return "受限制"
        case .denied: return "已拒绝"
        case .authorizedAlways: return "始终允许"
        case .authorizedWhenInUse: return "使用时允许"
        @unknown default: return "未知"
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    /// 授权状态变化回调
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let oldStatus = authorizationStatus
        authorizationStatus = manager.authorizationStatus

        print("📍 授权状态变化: \(authorizationStatusText)")

        // 如果刚获得授权，自动开始定位
        if oldStatus == .notDetermined && isAuthorized {
            print("📍 首次获得授权，自动开始定位")
            startUpdatingLocation()
        }
    }

    /// 位置更新回调
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 更新用户位置坐标
        userLocation = location.coordinate

        // ⭐ 关键：更新 currentLocation 供 Timer 采点使用
        currentLocation = location

        locationError = nil

        // 只在非追踪状态下打印位置更新日志（追踪时日志太多）
        if !isTracking {
            print("📍 位置更新: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
        }
    }

    /// 定位失败回调
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 定位失败: \(error.localizedDescription)")

        // 处理特定错误
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                locationError = "定位权限被拒绝，请在设置中开启"
            case .locationUnknown:
                locationError = "无法确定位置，请稍后重试"
            case .network:
                locationError = "网络错误，请检查网络连接"
            default:
                locationError = "定位失败: \(error.localizedDescription)"
            }
        } else {
            locationError = "定位失败: \(error.localizedDescription)"
        }
    }
}
