//
//  TerritoryManager.swift
//  EarthLord day7
//
//  领地管理器
//  负责领地数据的上传、加载、格式转换
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 领地管理器
@MainActor
class TerritoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = TerritoryManager()

    // MARK: - 发布的状态

    /// 当前用户的所有领地
    @Published var territories: [Territory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// 上传成功的领地 ID（用于 UI 反馈）
    @Published var lastUploadedTerritoryId: UUID? = nil

    // MARK: - 初始化

    private init() {
        print("📍 TerritoryManager 初始化完成")
    }

    // MARK: - 坐标转换方法

    /// 将坐标数组转换为 JSON 字符串
    /// 格式: [[lat, lon], [lat, lon], ...]
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: JSON 字符串
    func coordinatesToPathJSON(_ coordinates: [CLLocationCoordinate2D]) -> String {
        let points = coordinates.map { [$0.latitude, $0.longitude] }

        do {
            let data = try JSONEncoder().encode(points)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            print("❌ 坐标转 JSON 失败: \(error)")
            return "[]"
        }
    }

    /// 将坐标数组转换为 WKT (Well-Known Text) 格式
    /// ⚠️ 重要：WKT 格式是 longitude(经度) 在前，latitude(纬度) 在后！
    /// ⚠️ 重要：多边形必须闭合（首尾坐标相同）
    /// 格式: POLYGON((lon1 lat1, lon2 lat2, ..., lon1 lat1))
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: WKT 字符串
    func coordinatesToWKT(_ coordinates: [CLLocationCoordinate2D]) -> String {
        guard coordinates.count >= 3 else {
            print("⚠️ WKT 转换失败：坐标点数不足（需要至少 3 个点）")
            return "POLYGON EMPTY"
        }

        // 构建坐标字符串（经度在前，纬度在后）
        var coordStrings = coordinates.map { coord in
            "\(coord.longitude) \(coord.latitude)"
        }

        // 确保多边形闭合（首尾坐标相同）
        if let first = coordinates.first, let last = coordinates.last {
            let isClosed = (first.latitude == last.latitude && first.longitude == last.longitude)
            if !isClosed {
                // 添加闭合点
                coordStrings.append("\(first.longitude) \(first.latitude)")
            }
        }

        let wkt = "POLYGON((\(coordStrings.joined(separator: ", "))))"
        return wkt
    }

    /// 计算坐标数组的边界框
    /// - Parameter coordinates: CLLocationCoordinate2D 数组
    /// - Returns: (minLat, maxLat, minLon, maxLon) 元组
    func calculateBoundingBox(_ coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        guard !coordinates.isEmpty else {
            return (0, 0, 0, 0)
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
    }

    // MARK: - 上传方法

    /// 上传领地到 Supabase
    /// - Parameters:
    ///   - pathCoordinates: 路径坐标数组
    ///   - area: 领地面积（平方米）
    ///   - startTime: 开始圈地时间
    ///   - endTime: 完成圈地时间
    /// - Returns: 是否上传成功
    @discardableResult
    func uploadTerritory(
        pathCoordinates: [CLLocationCoordinate2D],
        area: Double,
        startTime: Date?,
        endTime: Date?
    ) async -> Bool {
        print("📤 [上传领地] 开始上传，坐标点数: \(pathCoordinates.count)，面积: \(String(format: "%.0f", area))m²")

        isLoading = true
        errorMessage = nil
        lastUploadedTerritoryId = nil

        // 1. 获取当前用户 ID
        guard let userId = await getCurrentUserId() else {
            errorMessage = "未登录，无法上传领地"
            print("❌ [上传领地] 未登录")
            isLoading = false
            return false
        }

        print("📤 [上传领地] 用户 ID: \(userId)")

        // 2. 转换坐标数据
        let pathJSON = coordinatesToPathJSON(pathCoordinates)
        let polygonWKT = coordinatesToWKT(pathCoordinates)
        let bbox = calculateBoundingBox(pathCoordinates)

        print("📤 [上传领地] 路径 JSON 长度: \(pathJSON.count)")
        print("📤 [上传领地] WKT: \(polygonWKT.prefix(100))...")
        print("📤 [上传领地] 边界框: (\(String(format: "%.6f", bbox.minLat)), \(String(format: "%.6f", bbox.maxLat)), \(String(format: "%.6f", bbox.minLon)), \(String(format: "%.6f", bbox.maxLon)))")

        // 3. 构建上传数据
        let territoryData = TerritoryInsert(
            userId: userId,
            name: nil,  // 默认无名称
            path: pathJSON,
            polygon: polygonWKT,
            bboxMinLat: bbox.minLat,
            bboxMaxLat: bbox.maxLat,
            bboxMinLon: bbox.minLon,
            bboxMaxLon: bbox.maxLon,
            area: area,
            pointCount: pathCoordinates.count,
            startedAt: startTime,
            completedAt: endTime,
            isActive: true
        )

        // 4. 上传到 Supabase
        do {
            let response: Territory = try await supabase
                .from("territories")
                .insert(territoryData)
                .select()
                .single()
                .execute()
                .value

            lastUploadedTerritoryId = response.id
            print("✅ [上传领地] 上传成功！ID: \(response.id)")
            TerritoryLogger.shared.log("领地上传成功！面积: \(Int(area))m²，ID: \(response.id)", type: .success)

            // 刷新领地列表
            await loadAllTerritories()

            isLoading = false
            return true

        } catch {
            errorMessage = "上传失败: \(error.localizedDescription)"
            print("❌ [上传领地] 上传失败: \(error)")
            TerritoryLogger.shared.log("领地上传失败: \(error.localizedDescription)", type: .error)
            isLoading = false
            return false
        }
    }

    // MARK: - 加载方法

    /// 加载当前用户的所有领地
    func loadAllTerritories() async {
        print("📥 [加载领地] 开始加载...")

        isLoading = true
        errorMessage = nil

        // 1. 获取当前用户 ID
        guard let userId = await getCurrentUserId() else {
            errorMessage = "未登录，无法加载领地"
            print("❌ [加载领地] 未登录")
            isLoading = false
            return
        }

        // 2. 从 Supabase 查询
        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            territories = response
            print("✅ [加载领地] 加载成功，共 \(territories.count) 块领地")

        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
            print("❌ [加载领地] 加载失败: \(error)")
        }

        isLoading = false
    }

    /// 加载指定 ID 的领地
    /// - Parameter id: 领地 ID
    /// - Returns: Territory 或 nil
    func loadTerritory(id: UUID) async -> Territory? {
        print("📥 [加载领地] 加载 ID: \(id)")

        do {
            let response: Territory = try await supabase
                .from("territories")
                .select()
                .eq("id", value: id.uuidString)
                .single()
                .execute()
                .value

            print("✅ [加载领地] 加载成功: \(id)")
            return response

        } catch {
            print("❌ [加载领地] 加载失败: \(error)")
            return nil
        }
    }

    // MARK: - 我的领地方法

    /// 加载我的激活领地（用于领地列表页面）
    /// - Returns: 我的领地数组
    func loadMyTerritories() async -> [Territory] {
        print("📥 [加载我的领地] 开始加载...")

        guard let userId = await getCurrentUserId() else {
            print("❌ [加载我的领地] 未登录")
            return []
        }

        do {
            let response: [Territory] = try await supabase
                .from("territories")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            print("✅ [加载我的领地] 加载成功，共 \(response.count) 块领地")
            return response

        } catch {
            print("❌ [加载我的领地] 加载失败: \(error)")
            return []
        }
    }

    /// 删除领地
    /// - Parameter territoryId: 领地 ID
    /// - Returns: 是否删除成功
    func deleteTerritory(territoryId: UUID) async -> Bool {
        print("🗑️ [删除领地] 开始删除，ID: \(territoryId)")

        do {
            try await supabase
                .from("territories")
                .delete()
                .eq("id", value: territoryId.uuidString)
                .execute()

            print("✅ [删除领地] 删除成功")
            TerritoryLogger.shared.log("领地已删除: \(territoryId)", type: .info)

            // 从本地列表中移除
            territories.removeAll { $0.id == territoryId }

            return true

        } catch {
            print("❌ [删除领地] 删除失败: \(error)")
            TerritoryLogger.shared.log("删除领地失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    /// 计算我的领地总面积
    var totalArea: Double {
        territories.filter { $0.isActive }.reduce(0) { $0 + $1.area }
    }

    /// 格式化总面积
    var formattedTotalArea: String {
        let total = totalArea
        if total >= 1_000_000 {
            return String(format: "%.2f km²", total / 1_000_000)
        } else {
            return String(format: "%.0f m²", total)
        }
    }

    // MARK: - 碰撞检测算法

    /// 射线法判断点是否在多边形内
    /// - Parameters:
    ///   - point: 要检测的点
    ///   - polygon: 多边形顶点数组
    /// - Returns: 点是否在多边形内
    func isPointInPolygon(point: CLLocationCoordinate2D, polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        let x = point.longitude
        let y = point.latitude

        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > y) != (yj > y)) &&
                           (x < (xj - xi) * (y - yi) / (yj - yi) + xi)

            if intersect {
                inside.toggle()
            }
            j = i
        }

        return inside
    }

    /// 检查起始点是否在他人领地内
    /// - Parameters:
    ///   - location: 起始点位置
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPointCollision(location: CLLocationCoordinate2D, currentUserId: String) -> CollisionResult {
        let otherTerritories = territories.filter { territory in
            territory.userId.uuidString.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else {
            return .safe
        }

        for territory in otherTerritories {
            let polygon = territory.coordinates
            guard polygon.count >= 3 else { continue }

            if isPointInPolygon(point: location, polygon: polygon) {
                TerritoryLogger.shared.log("起点碰撞：位于他人领地内", type: .error)
                return CollisionResult(
                    hasCollision: true,
                    collisionType: .pointInTerritory,
                    message: "不能在他人领地内开始圈地！",
                    closestDistance: 0,
                    warningLevel: .violation
                )
            }
        }

        return .safe
    }

    /// 判断两条线段是否相交（CCW 算法）
    /// - Parameters:
    ///   - p1: 线段1起点
    ///   - p2: 线段1终点
    ///   - p3: 线段2起点
    ///   - p4: 线段2终点
    /// - Returns: 是否相交
    private func segmentsIntersect(
        p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
        p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D
    ) -> Bool {
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            return (C.latitude - A.latitude) * (B.longitude - A.longitude) >
                   (B.latitude - A.latitude) * (C.longitude - A.longitude)
        }

        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检查路径是否穿越他人领地边界
    /// - Parameters:
    ///   - path: 路径坐标数组
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPathCrossTerritory(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        let otherTerritories = territories.filter { territory in
            territory.userId.uuidString.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return .safe }

        for i in 0..<(path.count - 1) {
            let pathStart = path[i]
            let pathEnd = path[i + 1]

            for territory in otherTerritories {
                let polygon = territory.coordinates
                guard polygon.count >= 3 else { continue }

                // 检查与领地每条边的相交
                for j in 0..<polygon.count {
                    let boundaryStart = polygon[j]
                    let boundaryEnd = polygon[(j + 1) % polygon.count]

                    if segmentsIntersect(p1: pathStart, p2: pathEnd, p3: boundaryStart, p4: boundaryEnd) {
                        TerritoryLogger.shared.log("路径碰撞：轨迹穿越他人领地边界", type: .error)
                        return CollisionResult(
                            hasCollision: true,
                            collisionType: .pathCrossTerritory,
                            message: "轨迹不能穿越他人领地！",
                            closestDistance: 0,
                            warningLevel: .violation
                        )
                    }
                }

                // 检查路径点是否在领地内
                if isPointInPolygon(point: pathEnd, polygon: polygon) {
                    TerritoryLogger.shared.log("路径碰撞：轨迹点进入他人领地", type: .error)
                    return CollisionResult(
                        hasCollision: true,
                        collisionType: .pointInTerritory,
                        message: "轨迹不能进入他人领地！",
                        closestDistance: 0,
                        warningLevel: .violation
                    )
                }
            }
        }

        return .safe
    }

    /// 计算当前位置到他人领地的最近距离
    /// - Parameters:
    ///   - location: 当前位置
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 最近距离（米）
    func calculateMinDistanceToTerritories(location: CLLocationCoordinate2D, currentUserId: String) -> Double {
        let otherTerritories = territories.filter { territory in
            territory.userId.uuidString.lowercased() != currentUserId.lowercased()
        }

        guard !otherTerritories.isEmpty else { return Double.infinity }

        var minDistance = Double.infinity
        let currentLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        for territory in otherTerritories {
            let polygon = territory.coordinates

            for vertex in polygon {
                let vertexLocation = CLLocation(latitude: vertex.latitude, longitude: vertex.longitude)
                let distance = currentLocation.distance(from: vertexLocation)
                minDistance = min(minDistance, distance)
            }
        }

        return minDistance
    }

    /// 综合碰撞检测（主方法）
    /// - Parameters:
    ///   - path: 路径坐标数组
    ///   - currentUserId: 当前用户 ID
    /// - Returns: 碰撞检测结果
    func checkPathCollisionComprehensive(path: [CLLocationCoordinate2D], currentUserId: String) -> CollisionResult {
        guard path.count >= 2 else { return .safe }

        // 1. 检查路径是否穿越他人领地
        let crossResult = checkPathCrossTerritory(path: path, currentUserId: currentUserId)
        if crossResult.hasCollision {
            return crossResult
        }

        // 2. 计算到最近领地的距离
        guard let lastPoint = path.last else { return .safe }
        let minDistance = calculateMinDistanceToTerritories(location: lastPoint, currentUserId: currentUserId)

        // 3. 根据距离确定预警级别和消息
        let warningLevel: WarningLevel
        let message: String?

        if minDistance > 100 {
            warningLevel = .safe
            message = nil
        } else if minDistance > 50 {
            warningLevel = .caution
            message = "注意：距离他人领地 \(Int(minDistance))m"
        } else if minDistance > 25 {
            warningLevel = .warning
            message = "警告：正在靠近他人领地（\(Int(minDistance))m）"
        } else {
            warningLevel = .danger
            message = "危险：即将进入他人领地！（\(Int(minDistance))m）"
        }

        if warningLevel != .safe {
            TerritoryLogger.shared.log("距离预警：\(warningLevel.description)，距离 \(Int(minDistance))m", type: .warning)
        }

        return CollisionResult(
            hasCollision: false,
            collisionType: nil,
            message: message,
            closestDistance: minDistance,
            warningLevel: warningLevel
        )
    }

    // MARK: - 辅助方法

    /// 获取当前登录用户的 ID
    /// - Returns: 用户 UUID 或 nil
    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            print("❌ 获取用户 ID 失败: \(error)")
            return nil
        }
    }
}
