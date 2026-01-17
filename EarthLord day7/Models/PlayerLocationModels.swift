//
//  PlayerLocationModels.swift
//  EarthLord day7
//
//  玩家位置相关数据模型
//  包含数据库映射模型和密度等级枚举
//

import Foundation

// MARK: - 数据库玩家位置（映射 player_locations 表）

/// 玩家位置（数据库模型）
struct DBPlayerLocation: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let isOnline: Bool
    let updatedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case isOnline = "is_online"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
    }
}

/// 插入/更新玩家位置（Upsert用）
struct DBPlayerLocationUpsert: Codable {
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case latitude
        case longitude
        case isOnline = "is_online"
    }
}

/// 更新在线状态
struct DBPlayerLocationOnlineUpdate: Codable {
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case isOnline = "is_online"
    }
}

// MARK: - 玩家密度等级枚举

/// 玩家密度等级
/// 根据附近玩家数量动态调整POI显示数量
enum PlayerDensityLevel: String, CaseIterable {
    case solo       // 独行者：0人附近
    case low        // 低密度：1-5人
    case medium     // 中密度：6-20人
    case high       // 高密度：20人以上

    /// 根据附近玩家数量返回密度等级
    /// - Parameter playerCount: 附近玩家数量（不包括自己）
    /// - Returns: 密度等级
    static func from(playerCount: Int) -> PlayerDensityLevel {
        switch playerCount {
        case 0:
            return .solo
        case 1...5:
            return .low
        case 6...20:
            return .medium
        default:
            return .high
        }
    }

    /// 该密度等级下最大POI显示数量
    var maxPOICount: Int {
        switch self {
        case .solo:
            return 1    // 独行时只显示1个POI，保证有地方探索
        case .low:
            return 3    // 低密度显示3个
        case .medium:
            return 6    // 中密度显示6个
        case .high:
            return 20   // 高密度显示全部
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .solo:
            return "独行者"
        case .low:
            return "低密度"
        case .medium:
            return "中密度"
        case .high:
            return "高密度"
        }
    }

    /// 描述信息
    var description: String {
        switch self {
        case .solo:
            return "附近没有其他幸存者"
        case .low:
            return "附近有少量幸存者活动"
        case .medium:
            return "这里聚集了一些幸存者"
        case .high:
            return "这是一个热门聚集地"
        }
    }
}
