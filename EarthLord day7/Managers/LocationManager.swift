//
//  LocationManager.swift
//  EarthLord day7
//
//  GPS 定位管理器
//  负责请求定位权限、获取用户位置、处理定位错误、路径追踪、闭环检测、速度检测
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

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    // MARK: - 发布的状态（速度检测）

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - 私有属性（路径追踪）

    /// 当前位置（供 Timer 采点使用）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 采点间隔（秒）
    private let trackingInterval: TimeInterval = 2.0

    /// 最小移动距离（米）- 移动超过此距离才记录新点
    private let minimumDistance: CLLocationDistance = 10.0

    // MARK: - 私有属性（闭环检测）

    /// 闭环距离阈值（米）- 距离起点小于此值视为闭环
    private let closureDistanceThreshold: CLLocationDistance = 30.0

    /// 最少路径点数 - 至少需要这么多点才检测闭环
    private let minimumPathPoints: Int = 10

    // MARK: - 私有属性（速度检测）

    /// 上次记录点的位置（用于速度计算）
    private var lastRecordedLocation: CLLocation?

    /// 上次记录点的时间戳（用于速度计算）
    private var lastRecordedTimestamp: Date?

    /// 警告速度阈值 (km/h) - 超过此速度显示警告
    private let warningSpeedThreshold: Double = 15.0

    /// 停止速度阈值 (km/h) - 超过此速度停止追踪
    private let stopSpeedThreshold: Double = 30.0

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
            TerritoryLogger.shared.log("未获得定位授权，无法开始路径追踪", type: .error)
            return
        }

        print("🚶 开始路径追踪...")
        TerritoryLogger.shared.log("开始路径追踪", type: .info)

        // 清除之前的路径
        clearPath()

        // 重置速度检测状态
        lastRecordedLocation = nil
        lastRecordedTimestamp = nil
        speedWarning = nil
        isOverSpeed = false

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
            // 记录第一个点的位置和时间戳
            lastRecordedLocation = location
            lastRecordedTimestamp = Date()
            print("📍 记录起始点: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
            TerritoryLogger.shared.log("记录起始点: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))", type: .info)
        }

        // 启动定时器，每 2 秒检查一次是否需要记录新点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: trackingInterval, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }

        print("⏱️ 采点定时器已启动，间隔: \(trackingInterval)秒")
        TerritoryLogger.shared.log("采点定时器已启动，间隔: \(trackingInterval)秒", type: .info)
    }

    /// 停止路径追踪
    func stopPathTracking() {
        print("🛑 停止路径追踪，共记录 \(pathCoordinates.count) 个点")
        TerritoryLogger.shared.log("停止路径追踪，共记录 \(pathCoordinates.count) 个点", type: .info)

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
        TerritoryLogger.shared.log("清除路径数据", type: .info)
        pathCoordinates.removeAll()
        pathUpdateVersion += 1
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
    }

    // MARK: - 私有方法（路径追踪）

    /// 定时器回调 - 记录路径点
    /// ⚠️ 关键：先检查距离，再检查速度！顺序不能反！
    private func recordPathPoint() {
        guard isTracking else { return }
        guard let location = currentLocation else {
            print("⚠️ 当前位置为空，跳过采点")
            return
        }

        // 步骤1：先检查距离（过滤 GPS 漂移，距离不够就直接返回）
        if let lastCoordinate = pathCoordinates.last {
            let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
            let distance = location.distance(from: lastLocation)

            // 只有移动超过最小距离才继续
            guard distance >= minimumDistance else {
                print("📍 移动距离不足 (\(String(format: "%.1f", distance))m < \(minimumDistance)m)，跳过采点")
                return
            }

            print("📍 移动距离: \(String(format: "%.1f", distance))m，准备记录新点")
        }

        // 步骤2：再检查速度（只对真实移动进行检测）
        guard validateMovementSpeed(newLocation: location) else {
            print("🚫 严重超速，不记录该点")
            return
        }

        // 步骤3：记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1

        // 更新上次记录的位置和时间戳
        lastRecordedLocation = location
        lastRecordedTimestamp = Date()

        print("📍 记录第 \(pathCoordinates.count) 个点: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))")
        TerritoryLogger.shared.log("记录第 \(pathCoordinates.count) 个点: (\(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude)))", type: .info)

        // 步骤4：检测闭环
        checkPathClosure()
    }

    // MARK: - 私有方法（闭环检测）

    /// 检测路径是否闭合
    private func checkPathClosure() {
        // 已经闭合就不再检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("🔄 闭环检测：点数不足 (\(pathCoordinates.count) < \(minimumPathPoints))")
            return
        }

        // 获取起点和当前点
        guard let startCoordinate = pathCoordinates.first,
              let currentCoordinate = pathCoordinates.last else {
            return
        }

        // 计算当前位置到起点的距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let currentLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        let distanceToStart = currentLocation.distance(from: startLocation)

        print("🔄 闭环检测：距离起点 \(String(format: "%.1f", distanceToStart))m，阈值 \(closureDistanceThreshold)m")

        // 判断是否闭环
        if distanceToStart <= closureDistanceThreshold {
            isPathClosed = true
            pathUpdateVersion += 1  // 触发 UI 更新
            print("✅ 闭环检测成功！路径已闭合，共 \(pathCoordinates.count) 个点")
            TerritoryLogger.shared.log("闭环检测成功！路径已闭合，共 \(pathCoordinates.count) 个点，距离起点 \(String(format: "%.1f", distanceToStart))m", type: .success)
        } else {
            print("⏳ 闭环检测：尚未闭合，继续追踪...")
        }
    }

    // MARK: - 私有方法（速度检测）

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true 表示可以记录该点，false 表示不记录（严重超速）
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 如果没有上次记录的位置，这是第一个点，允许记录
        guard let lastLocation = lastRecordedLocation,
              let lastTimestamp = lastRecordedTimestamp else {
            return true
        }

        // 计算距离（米）
        let distance = newLocation.distance(from: lastLocation)

        // 计算时间差（秒）
        let timeInterval = Date().timeIntervalSince(lastTimestamp)

        // 避免除以零
        guard timeInterval > 0 else { return true }

        // 计算速度 (m/s → km/h)
        let speedMPS = distance / timeInterval
        let speedKMH = speedMPS * 3.6

        print("🚗 速度检测：距离 \(String(format: "%.1f", distance))m，时间 \(String(format: "%.1f", timeInterval))s，速度 \(String(format: "%.1f", speedKMH)) km/h")

        // 检查是否严重超速（>30 km/h）
        if speedKMH > stopSpeedThreshold {
            speedWarning = "移动速度过快（\(String(format: "%.0f", speedKMH)) km/h），已暂停追踪"
            isOverSpeed = true
            print("🚨 严重超速！速度 \(String(format: "%.1f", speedKMH)) km/h > \(stopSpeedThreshold) km/h，停止追踪")
            TerritoryLogger.shared.log("严重超速！速度 \(String(format: "%.1f", speedKMH)) km/h > \(stopSpeedThreshold) km/h，停止追踪", type: .error)

            // 停止追踪
            stopPathTracking()

            // 3秒后清除警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.speedWarning = nil
            }

            return false
        }

        // 检查是否轻微超速（>15 km/h）
        if speedKMH > warningSpeedThreshold {
            speedWarning = "移动速度较快（\(String(format: "%.0f", speedKMH)) km/h），请步行"
            isOverSpeed = true
            print("⚠️ 轻微超速：速度 \(String(format: "%.1f", speedKMH)) km/h > \(warningSpeedThreshold) km/h，警告但继续记录")
            TerritoryLogger.shared.log("速度警告：\(String(format: "%.1f", speedKMH)) km/h，超过 \(warningSpeedThreshold) km/h", type: .warning)

            // 3秒后清除警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.speedWarning = nil
                self?.isOverSpeed = false
            }

            return true  // 警告但继续记录
        }

        // 速度正常
        if isOverSpeed {
            isOverSpeed = false
            speedWarning = nil
        }

        return true
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
