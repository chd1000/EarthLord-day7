//
//  BuildingModels.swift
//  EarthLord day7
//
//  建造系统数据模型
//  包含建筑分类、状态、模板定义、玩家建筑实例
//

import Foundation
import SwiftUI

// MARK: - 建筑分类枚举

/// 建筑分类
enum BuildingCategory: String, Codable, CaseIterable {
    case survival = "survival"       // 生存
    case storage = "storage"         // 储存
    case production = "production"   // 生产
    case energy = "energy"           // 能源

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .survival: return String(localized: "building_category_survival")
        case .storage: return String(localized: "building_category_storage")
        case .production: return String(localized: "building_category_production")
        case .energy: return String(localized: "building_category_energy")
        }
    }

    /// SF Symbol 图标
    var icon: String {
        switch self {
        case .survival: return "flame.fill"
        case .storage: return "archivebox.fill"
        case .production: return "gearshape.fill"
        case .energy: return "bolt.fill"
        }
    }
}

// MARK: - 建筑状态枚举

/// 建筑状态
enum BuildingStatus: String, Codable {
    case constructing = "constructing"  // 建造中
    case active = "active"              // 运行中

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .constructing: return String(localized: "building_status_constructing")
        case .active: return String(localized: "building_status_active")
        }
    }

    /// 状态颜色
    var color: Color {
        switch self {
        case .constructing: return .blue
        case .active: return .green
        }
    }
}

// MARK: - 建筑模板（从 JSON 加载）

/// 建筑模板定义
struct BuildingTemplate: Codable, Identifiable {
    let id: String
    let templateId: String
    let name: String
    let category: String
    let tier: Int
    let description: String
    let icon: String
    let requiredResources: [String: Int]
    let buildTimeSeconds: Int
    let maxPerTerritory: Int
    let maxLevel: Int

    /// 获取建筑分类枚举
    var categoryEnum: BuildingCategory {
        BuildingCategory(rawValue: category) ?? .survival
    }

    /// 本地化建筑名称
    var localizedName: String {
        String(localized: String.LocalizationValue(name))
    }

    /// 本地化建筑描述
    var localizedDescription: String {
        String(localized: String.LocalizationValue(description))
    }

    /// 等级显示文本
    var tierDisplayText: String {
        "T\(tier)"
    }
}

/// 建筑模板列表（用于 JSON 解码）
struct BuildingTemplateList: Codable {
    let templates: [BuildingTemplate]
}

// MARK: - 玩家建筑（数据库映射）

/// 玩家已建造的建筑
struct PlayerBuilding: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    var status: String
    var level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildStartedAt: Date?
    var buildCompletedAt: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildStartedAt = "build_started_at"
        case buildCompletedAt = "build_completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 获取建筑状态枚举
    var statusEnum: BuildingStatus {
        BuildingStatus(rawValue: status) ?? .constructing
    }

    /// 检查建造是否完成
    var isConstructionComplete: Bool {
        if let completedAt = buildCompletedAt {
            return Date() >= completedAt
        }
        return false
    }

    /// 计算建造剩余时间（秒）
    func remainingBuildTime(template: BuildingTemplate?) -> Int {
        guard let completedAt = buildCompletedAt else { return 0 }
        let remaining = completedAt.timeIntervalSince(Date())
        return max(0, Int(remaining))
    }
}

/// 插入玩家建筑（不含自动生成的字段）
struct PlayerBuildingInsert: Codable {
    let userId: UUID
    let territoryId: String
    let templateId: String
    let buildingName: String
    let status: String
    let level: Int
    let locationLat: Double?
    let locationLon: Double?
    let buildCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case territoryId = "territory_id"
        case templateId = "template_id"
        case buildingName = "building_name"
        case status
        case level
        case locationLat = "location_lat"
        case locationLon = "location_lon"
        case buildCompletedAt = "build_completed_at"
    }
}

/// 更新玩家建筑
struct PlayerBuildingUpdate: Codable {
    var status: String?
    var level: Int?
    var buildCompletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case level
        case buildCompletedAt = "build_completed_at"
    }
}

// MARK: - 建筑错误

/// 建筑系统错误
enum BuildingError: Error, LocalizedError {
    case insufficientResources([String: Int])  // 资源不足，包含缺少的资源
    case maxBuildingsReached(Int)              // 达到建筑数量上限
    case templateNotFound                       // 模板未找到
    case invalidStatus                          // 状态无效（如建造中无法升级）
    case maxLevelReached                        // 达到最大等级
    case databaseError(String)                  // 数据库错误

    var errorDescription: String? {
        switch self {
        case .insufficientResources(let missing):
            let resourceList = missing.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return String(localized: "building_error_insufficient_resources") + " (\(resourceList))"
        case .maxBuildingsReached(let max):
            return String(localized: "building_error_max_reached") + " (\(max))"
        case .templateNotFound:
            return String(localized: "building_error_template_not_found")
        case .invalidStatus:
            return String(localized: "building_error_invalid_status")
        case .maxLevelReached:
            return String(localized: "building_error_max_level")
        case .databaseError(let message):
            return String(localized: "building_error_database") + ": \(message)"
        }
    }
}

// MARK: - 建造检查结果

/// 建造可行性检查结果
struct BuildCheckResult {
    let canBuild: Bool
    let missingResources: [String: Int]
    let currentCount: Int
    let maxCount: Int

    /// 创建成功结果
    static func success(currentCount: Int, maxCount: Int) -> BuildCheckResult {
        BuildCheckResult(canBuild: true, missingResources: [:], currentCount: currentCount, maxCount: maxCount)
    }

    /// 创建资源不足结果
    static func insufficientResources(_ missing: [String: Int], currentCount: Int, maxCount: Int) -> BuildCheckResult {
        BuildCheckResult(canBuild: false, missingResources: missing, currentCount: currentCount, maxCount: maxCount)
    }

    /// 创建数量上限结果
    static func maxReached(currentCount: Int, maxCount: Int) -> BuildCheckResult {
        BuildCheckResult(canBuild: false, missingResources: [:], currentCount: currentCount, maxCount: maxCount)
    }
}
