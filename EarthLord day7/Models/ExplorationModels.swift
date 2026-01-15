//
//  ExplorationModels.swift
//  EarthLord day7
//
//  探索功能相关数据模型
//  包含奖励等级、数据库映射模型、UI显示模型
//

import Foundation

// MARK: - 奖励等级枚举

/// 探索奖励等级
enum RewardTier: String, Codable, CaseIterable {
    case none = "none"           // 无奖励 (<200m)
    case bronze = "bronze"       // 铜级 (200-500m)
    case silver = "silver"       // 银级 (500-1000m)
    case gold = "gold"           // 金级 (1000-2000m)
    case diamond = "diamond"     // 钻石级 (>2000m)

    /// 根据距离判定等级
    static func from(distance: Double) -> RewardTier {
        switch distance {
        case ..<200: return .none
        case 200..<500: return .bronze
        case 500..<1000: return .silver
        case 1000..<2000: return .gold
        default: return .diamond
        }
    }

    /// 物品数量
    var itemCount: Int {
        switch self {
        case .none: return 0
        case .bronze: return 1
        case .silver: return 2
        case .gold: return 3
        case .diamond: return 5
        }
    }

    /// 稀有度概率分布 [common, rare, epic]
    var rarityProbabilities: [Double] {
        switch self {
        case .none: return [0, 0, 0]
        case .bronze: return [0.90, 0.10, 0.00]
        case .silver: return [0.70, 0.25, 0.05]
        case .gold: return [0.50, 0.35, 0.15]
        case .diamond: return [0.30, 0.40, 0.30]
        }
    }

    /// 显示名称
    var displayName: String {
        switch self {
        case .none: return "无奖励"
        case .bronze: return "铜级"
        case .silver: return "银级"
        case .gold: return "金级"
        case .diamond: return "钻石级"
        }
    }

    /// 显示图标
    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .bronze: return "medal"
        case .silver: return "medal.fill"
        case .gold: return "star.fill"
        case .diamond: return "sparkles"
        }
    }

    /// 显示颜色名称（用于UI）
    var colorName: String {
        switch self {
        case .none: return "gray"
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .diamond: return "cyan"
        }
    }
}

// MARK: - 数据库物品定义（映射 item_definitions 表）

/// 物品定义（数据库模型）
struct DBItemDefinition: Codable, Identifiable {
    let id: String           // "water_bottle"
    let name: String         // "纯净水"
    let description: String?
    let icon: String         // SF Symbol 名称
    let rarity: String       // "common" | "rare" | "epic"
    let category: String     // "food" | "medical" | "tool" | "material" | "equipment"
    let weight: Double?
    let maxStack: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, category, weight
        case maxStack = "max_stack"
        case createdAt = "created_at"
    }

    /// 稀有度显示名称
    var rarityDisplayName: String {
        switch rarity {
        case "common": return "普通"
        case "rare": return "稀有"
        case "epic": return "史诗"
        default: return rarity
        }
    }

    /// 分类显示名称
    var categoryDisplayName: String {
        switch category {
        case "food": return "食物"
        case "medical": return "医疗"
        case "tool": return "工具"
        case "material": return "材料"
        case "equipment": return "装备"
        default: return category
        }
    }
}

// MARK: - 数据库背包物品（映射 inventory_items 表）

/// 背包物品（数据库模型）
struct DBInventoryItem: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itemId: String
    var quantity: Int
    let obtainedAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
        case obtainedAt = "obtained_at"
        case updatedAt = "updated_at"
    }
}

/// 插入背包物品（不含自动生成的字段）
struct DBInventoryItemInsert: Codable {
    let userId: UUID
    let itemId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case itemId = "item_id"
        case quantity
    }
}

/// 更新背包物品数量
struct DBInventoryItemUpdate: Codable {
    let quantity: Int
}

// MARK: - 数据库探索会话（映射 exploration_sessions 表）

/// 探索会话（数据库模型）
struct DBExplorationSession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let startTime: Date
    var endTime: Date?
    var duration: Int?         // 秒
    var totalDistance: Double?
    var startLat: Double?
    var startLng: Double?
    var endLat: Double?
    var endLng: Double?
    var rewardTier: String?
    var itemsRewarded: String? // JSON 字符串
    var status: String         // "active" | "completed" | "cancelled"
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case totalDistance = "total_distance"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case rewardTier = "reward_tier"
        case itemsRewarded = "items_rewarded"
        case status
        case createdAt = "created_at"
    }
}

/// 插入探索会话
struct DBExplorationSessionInsert: Codable {
    let userId: UUID
    let startLat: Double?
    let startLng: Double?
    let status: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case startLat = "start_lat"
        case startLng = "start_lng"
        case status
    }
}

/// 更新探索会话
struct DBExplorationSessionUpdate: Codable {
    let endTime: Date?
    let duration: Int?
    let totalDistance: Double?
    let endLat: Double?
    let endLng: Double?
    let rewardTier: String?
    let itemsRewarded: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case endTime = "end_time"
        case duration
        case totalDistance = "total_distance"
        case endLat = "end_lat"
        case endLng = "end_lng"
        case rewardTier = "reward_tier"
        case itemsRewarded = "items_rewarded"
        case status
    }
}

// MARK: - 探索结果（用于 UI 显示）

/// 探索奖励结果
struct ExplorationRewardResult {
    let sessionId: UUID
    let distance: Double          // 行走距离（米）
    let duration: TimeInterval    // 探索时长（秒）
    let rewardTier: RewardTier
    let rewardedItems: [RewardedItem]

    /// 奖励物品
    struct RewardedItem: Identifiable {
        let id = UUID()
        let itemId: String
        let name: String
        let quantity: Int
        let rarity: String
        let icon: String
        let category: String
    }

    /// 格式化距离显示
    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    /// 格式化时长显示
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}
