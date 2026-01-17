//
//  PlayerLocationManager.swift
//  EarthLord day7
//
//  玩家位置管理器
//  负责位置上报、附近玩家查询、在线状态管理
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 玩家位置管理器
@MainActor
class PlayerLocationManager: ObservableObject {

    // MARK: - 单例

    static let shared = PlayerLocationManager()

    // MARK: - 发布的状态

    /// 附近玩家数量
    @Published var nearbyPlayerCount: Int = 0

    /// 当前密度等级
    @Published var densityLevel: PlayerDensityLevel = .solo

    /// 是否正在上报位置
    @Published var isReporting: Bool = false

    /// 上次上报时间
    @Published var lastReportTime: Date?

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 私有属性

    private var locationManager = LocationManager.shared
    private var reportTimer: Timer?
    private var lastReportedLocation: CLLocationCoordinate2D?

    /// 上报间隔（秒）- 每30秒上报一次
    private let reportInterval: TimeInterval = 30.0

    /// 最小上报距离（米）- 移动50米立即上报
    private let minReportDistance: Double = 50.0

    /// 查询附近玩家的半径（米）
    private let queryRadius: Double = 1000.0

    // MARK: - 初始化

    private init() {
        print("📍 PlayerLocationManager 初始化")
    }

    // MARK: - 公开方法

    /// 启动位置上报定时器
    func startLocationReporting() {
        guard reportTimer == nil else {
            print("📍 [位置上报] 定时器已在运行")
            return
        }

        print("📍 [位置上报] 启动定时上报，间隔: \(reportInterval)秒")

        // 立即上报一次
        Task {
            await reportLocation()
        }

        // 启动定时器
        reportTimer = Timer.scheduledTimer(withTimeInterval: reportInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.reportLocationIfNeeded()
            }
        }
    }

    /// 停止位置上报定时器
    func stopLocationReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
        print("📍 [位置上报] 已停止定时上报")
    }

    /// 上报当前位置到Supabase
    func reportLocation() async {
        guard let wgs84Location = locationManager.userLocation else {
            print("⚠️ [位置上报] 无法获取当前位置")
            return
        }

        // 获取用户ID
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [位置上报] 未登录，无法上报位置")
            return
        }

        isReporting = true

        // 将WGS-84转换为GCJ-02（火星坐标）
        let gcj02Location = CoordinateConverter.wgs84ToGcj02(wgs84Location)

        let upsert = DBPlayerLocationUpsert(
            userId: userId,
            latitude: gcj02Location.latitude,
            longitude: gcj02Location.longitude,
            isOnline: true
        )

        do {
            // Upsert操作：存在则更新，不存在则插入
            try await supabase
                .from("player_locations")
                .upsert(upsert, onConflict: "user_id")
                .execute()

            lastReportedLocation = gcj02Location
            lastReportTime = Date()
            errorMessage = nil

            print("📍 [位置上报] 成功: (\(String(format: "%.6f", gcj02Location.latitude)), \(String(format: "%.6f", gcj02Location.longitude)))")
        } catch {
            errorMessage = "位置上报失败: \(error.localizedDescription)"
            print("❌ [位置上报] 失败: \(error)")
        }

        isReporting = false
    }

    /// 查询附近玩家数量
    /// - Returns: 附近玩家数量（不包括自己）
    func queryNearbyPlayers() async -> Int {
        guard let wgs84Location = locationManager.userLocation else {
            print("⚠️ [附近查询] 无法获取当前位置")
            return 0
        }

        // 获取用户ID（用于排除自己）
        let userId = await getCurrentUserId()

        // 将WGS-84转换为GCJ-02
        let gcj02Location = CoordinateConverter.wgs84ToGcj02(wgs84Location)

        // 调用非隔离的RPC查询函数
        let result = await performNearbyPlayersQuery(
            lat: gcj02Location.latitude,
            lng: gcj02Location.longitude,
            radius: queryRadius,
            excludeUserId: userId?.uuidString
        )

        nearbyPlayerCount = result
        densityLevel = PlayerDensityLevel.from(playerCount: result)

        print("📍 [附近查询] 发现 \(result) 位附近玩家，密度等级: \(densityLevel.displayName)")

        return result
    }

    /// 执行附近玩家查询（非隔离函数，避免MainActor与Sendable冲突）
    nonisolated private func performNearbyPlayersQuery(
        lat: Double,
        lng: Double,
        radius: Double,
        excludeUserId: String?
    ) async -> Int {
        do {
            // 获取5分钟内在线的玩家位置
            let fiveMinutesAgo = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300))

            let response: [DBPlayerLocation] = try await supabase
                .from("player_locations")
                .select()
                .eq("is_online", value: true)
                .gte("updated_at", value: fiveMinutesAgo)
                .execute()
                .value

            // 在客户端计算距离并过滤
            var count = 0
            for player in response {
                // 排除自己
                if let excludeId = excludeUserId, player.userId.uuidString == excludeId {
                    continue
                }

                // 计算距离（Haversine公式）
                let distance = calculateDistance(
                    lat1: lat, lng1: lng,
                    lat2: player.latitude, lng2: player.longitude
                )

                if distance <= radius {
                    count += 1
                }
            }

            return count
        } catch {
            print("❌ [附近查询] 失败: \(error)")
            return 0
        }
    }

    /// 计算两点间距离（Haversine公式）
    nonisolated private func calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let earthRadius: Double = 6371000 // 米
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadius * c
    }

    /// 标记为离线
    func setOffline() async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [离线状态] 未登录，无法更新状态")
            return
        }

        let update = DBPlayerLocationOnlineUpdate(isOnline: false)

        do {
            try await supabase
                .from("player_locations")
                .update(update)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("📍 [离线状态] 已标记为离线")
        } catch {
            print("❌ [离线状态] 更新失败: \(error)")
        }
    }

    /// 标记为在线并上报位置
    func setOnlineAndReport() async {
        await reportLocation()
    }

    // MARK: - 私有方法

    /// 根据条件决定是否上报位置
    private func reportLocationIfNeeded() async {
        guard let currentLocation = locationManager.userLocation else { return }

        // 检查是否移动了足够距离
        if let lastLocation = lastReportedLocation {
            let lastCLLocation = CLLocation(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
            let currentCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            let distance = currentCLLocation.distance(from: lastCLLocation)

            if distance < minReportDistance {
                print("📍 [位置上报] 移动距离不足 (\(String(format: "%.0f", distance))m < \(minReportDistance)m)，跳过上报")
                return
            }
        }

        await reportLocation()
    }

    /// 获取当前用户ID
    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            print("❌ [用户ID] 获取失败: \(error)")
            return nil
        }
    }
}
