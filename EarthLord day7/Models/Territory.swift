//
//  Territory.swift
//  EarthLord day7
//
//  领地数据模型
//  对应 Supabase 数据库 territories 表
//

import Foundation
import CoreLocation

/// 领地数据模型
struct Territory: Codable, Identifiable {

    // MARK: - 属性

    /// 领地 ID（主键）
    let id: UUID

    /// 用户 ID（外键）
    let userId: UUID

    /// 领地名称（可选）
    var name: String?

    /// 路径坐标（JSON 字符串）
    let path: String

    /// PostGIS 多边形（WKT 格式，可选）
    let polygon: String?

    /// 边界框 - 最小纬度
    let bboxMinLat: Double

    /// 边界框 - 最大纬度
    let bboxMaxLat: Double

    /// 边界框 - 最小经度
    let bboxMinLon: Double

    /// 边界框 - 最大经度
    let bboxMaxLon: Double

    /// 领地面积（平方米）
    let area: Double

    /// 路径点数量
    let pointCount: Int

    /// 开始圈地时间
    let startedAt: Date?

    /// 完成圈地时间
    let completedAt: Date?

    /// 是否激活
    var isActive: Bool

    /// 创建时间
    let createdAt: Date

    // MARK: - CodingKeys（映射数据库字段名）

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case path
        case polygon
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case area
        case pointCount = "point_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    // MARK: - 计算属性

    /// 解析路径 JSON 获取坐标数组
    var coordinates: [CLLocationCoordinate2D] {
        guard let data = path.data(using: .utf8) else { return [] }

        do {
            // path 格式: [[lat, lon], [lat, lon], ...]
            let points = try JSONDecoder().decode([[Double]].self, from: data)
            return points.compactMap { point in
                guard point.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
            }
        } catch {
            print("❌ 解析领地坐标失败: \(error)")
            return []
        }
    }

    /// 格式化面积显示
    var formattedArea: String {
        if area >= 1_000_000 {
            return String(format: "%.2f km²", area / 1_000_000)
        } else {
            return String(format: "%.0f m²", area)
        }
    }

    /// 显示名称（无名称时显示默认值）
    var displayName: String {
        return name ?? "未命名领地"
    }

    /// 格式化创建时间
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: createdAt)
    }

    /// 计算领地中心点
    var centerCoordinate: CLLocationCoordinate2D {
        let centerLat = (bboxMinLat + bboxMaxLat) / 2
        let centerLon = (bboxMinLon + bboxMaxLon) / 2
        return CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
}

// MARK: - 用于上传的数据结构

/// 上传领地时使用的数据结构（不含 id 和 created_at）
struct TerritoryInsert: Codable {

    let userId: UUID
    var name: String?
    let path: String
    let polygon: String?
    let bboxMinLat: Double
    let bboxMaxLat: Double
    let bboxMinLon: Double
    let bboxMaxLon: Double
    let area: Double
    let pointCount: Int
    let startedAt: Date?
    let completedAt: Date?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case path
        case polygon
        case bboxMinLat = "bbox_min_lat"
        case bboxMaxLat = "bbox_max_lat"
        case bboxMinLon = "bbox_min_lon"
        case bboxMaxLon = "bbox_max_lon"
        case area
        case pointCount = "point_count"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case isActive = "is_active"
    }
}
