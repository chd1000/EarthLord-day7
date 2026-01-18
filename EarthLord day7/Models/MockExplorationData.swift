//
//  MockExplorationData.swift
//  EarthLord day7
//
//  探索模块测试假数据
//  用于开发和测试阶段，展示探索功能的各种状态
//

import Foundation
import CoreLocation

// MARK: - POI 状态枚举

/// 兴趣点发现状态
enum POIDiscoveryStatus: String, Codable {
    case undiscovered = "undiscovered"  // 未发现（地图上显示为问号）
    case discovered = "discovered"       // 已发现（可以查看详情）
    case looted = "looted"              // 已被搜空（无法再获取物资）
}

/// 兴趣点类型
enum POIType: String, Codable {
    case supermarket = "supermarket"    // 超市
    case hospital = "hospital"          // 医院
    case gasStation = "gas_station"     // 加油站
    case pharmacy = "pharmacy"          // 药店
    case factory = "factory"            // 工厂
    case warehouse = "warehouse"        // 仓库
    case house = "house"                // 民居
    case police = "police"              // 警察局
    case military = "military"          // 军事设施

    /// 类型显示名称
    var displayName: String {
        switch self {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .house: return "民居"
        case .police: return "警察局"
        case .military: return "军事设施"
        }
    }
}

// MARK: - POI 数据模型

/// 兴趣点（Point of Interest）
struct POI: Identifiable, Codable {
    let id: UUID
    let name: String                    // 地点名称
    let type: POIType                   // 地点类型
    let coordinate: Coordinate          // 坐标
    var status: POIDiscoveryStatus      // 发现状态
    var hasLoot: Bool                   // 是否有物资
    let dangerLevel: Int                // 危险等级（1-5）
    let description: String             // 描述

    // MARK: - POI搜刮系统扩展字段
    var distanceFromUser: Double?       // 与玩家的实时距离（米）
    var lastLootedAt: Date?             // 上次搜刮时间

    /// 坐标结构（用于 Codable）
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double

        var clLocationCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    /// 是否可以搜刮
    var canScavenge: Bool {
        hasLoot && status != .looted
    }

    /// 类型中文名
    var typeDisplayName: String {
        switch type {
        case .supermarket: return "超市"
        case .hospital: return "医院"
        case .gasStation: return "加油站"
        case .pharmacy: return "药店"
        case .factory: return "工厂"
        case .warehouse: return "仓库"
        case .house: return "民居"
        case .police: return "警察局"
        case .military: return "军事设施"
        }
    }

    /// 状态中文名
    var statusDisplayName: String {
        switch status {
        case .undiscovered: return "未探索"
        case .discovered: return "已发现"
        case .looted: return "已搜空"
        }
    }

    /// SF Symbol 图标名
    var iconName: String {
        switch type {
        case .supermarket: return "cart.fill"
        case .hospital: return "cross.case.fill"
        case .gasStation: return "fuelpump.fill"
        case .pharmacy: return "pills.fill"
        case .factory: return "building.2.fill"
        case .warehouse: return "shippingbox.fill"
        case .house: return "house.fill"
        case .police: return "shield.fill"
        case .military: return "airplane"
        }
    }
}

// MARK: - 搜刮结果模型

/// 搜刮结果
struct ScavengeResult: Identifiable {
    let id: UUID
    let poiId: UUID
    let poiName: String
    let poiType: POIType
    let items: [ScavengedItem]
    let timestamp: Date
    let isAIGenerated: Bool  // 是否为 AI 生成的物品

    init(poiId: UUID, poiName: String, poiType: POIType, items: [ScavengedItem], isAIGenerated: Bool = false) {
        self.id = UUID()
        self.poiId = poiId
        self.poiName = poiName
        self.poiType = poiType
        self.items = items
        self.timestamp = Date()
        self.isAIGenerated = isAIGenerated
    }

    /// 搜刮获得的物品
    struct ScavengedItem: Identifiable {
        let id: UUID
        let itemId: String
        let name: String
        let quantity: Int
        let rarity: String
        let icon: String
        let category: String
        let story: String?        // AI 生成的故事
        let isAIGenerated: Bool   // 是否为 AI 生成

        init(itemId: String, name: String, quantity: Int, rarity: String, icon: String, category: String, story: String? = nil, isAIGenerated: Bool = false) {
            self.id = UUID()
            self.itemId = itemId
            self.name = name
            self.quantity = quantity
            self.rarity = rarity
            self.icon = icon
            self.category = category
            self.story = story
            self.isAIGenerated = isAIGenerated
        }
    }
}

// MARK: - 物品相关枚举

/// 物品分类
enum ItemCategory: String, Codable {
    case water = "water"            // 水类
    case food = "food"              // 食物
    case medical = "medical"        // 医疗
    case material = "material"      // 材料
    case tool = "tool"              // 工具
    case weapon = "weapon"          // 武器
    case clothing = "clothing"      // 服装
    case misc = "misc"              // 杂项
}

/// 物品品质
enum ItemQuality: String, Codable {
    case broken = "broken"          // 破损
    case worn = "worn"              // 磨损
    case normal = "normal"          // 普通
    case good = "good"              // 良好
    case excellent = "excellent"    // 优秀

    /// 品质颜色（用于 UI 显示）
    var colorName: String {
        switch self {
        case .broken: return "gray"
        case .worn: return "brown"
        case .normal: return "white"
        case .good: return "green"
        case .excellent: return "blue"
        }
    }

    /// 品质中文名
    var displayName: String {
        switch self {
        case .broken: return "破损"
        case .worn: return "磨损"
        case .normal: return "普通"
        case .good: return "良好"
        case .excellent: return "优秀"
        }
    }
}

/// 物品稀有度
enum ItemRarity: String, Codable {
    case common = "common"          // 普通
    case uncommon = "uncommon"      // 少见
    case rare = "rare"              // 稀有
    case epic = "epic"              // 史诗
    case legendary = "legendary"    // 传说

    /// 稀有度颜色
    var colorName: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }

    /// 稀有度中文名
    var displayName: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "少见"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }
}

// MARK: - 物品定义模型

/// 物品定义（物品的基础属性，不包含数量和品质）
struct ItemDefinition: Identifiable, Codable {
    let id: String                  // 物品唯一标识符（如 "water_bottle"）
    let name: String                // 中文名称
    let category: ItemCategory      // 分类
    let weight: Double              // 单个重量（kg）
    let volume: Double              // 单个体积（L）
    let rarity: ItemRarity          // 稀有度
    let description: String         // 描述
    let stackable: Bool             // 是否可堆叠
    let maxStack: Int               // 最大堆叠数量
    let hasQuality: Bool            // 是否有品质属性

    /// 分类中文名
    var categoryDisplayName: String {
        switch category {
        case .water: return "水类"
        case .food: return "食物"
        case .medical: return "医疗"
        case .material: return "材料"
        case .tool: return "工具"
        case .weapon: return "武器"
        case .clothing: return "服装"
        case .misc: return "杂项"
        }
    }

    /// 分类图标
    var categoryIconName: String {
        switch category {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .material: return "cube.fill"
        case .tool: return "wrench.and.screwdriver.fill"
        case .weapon: return "bolt.fill"
        case .clothing: return "tshirt.fill"
        case .misc: return "questionmark.circle.fill"
        }
    }
}

// MARK: - 背包物品模型

/// 背包中的物品（包含数量和品质）
struct InventoryItem: Identifiable, Codable {
    let id: UUID                    // 实例 ID（用于区分同类物品）
    let itemId: String              // 物品定义 ID
    var quantity: Int               // 数量
    let quality: ItemQuality?       // 品质（部分物品没有品质）
    let obtainedAt: Date            // 获取时间

    /// 格式化获取时间
    var formattedObtainedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: obtainedAt)
    }
}

// MARK: - 探索结果模型

/// 探索统计数据
struct ExplorationStats: Codable {
    // 行走距离
    let walkDistanceThisTime: Double    // 本次行走距离（米）
    let walkDistanceTotal: Double       // 累计行走距离（米）
    let walkDistanceRank: Int           // 行走距离排名

    // 探索时长
    let explorationDuration: TimeInterval   // 探索时长（秒）

    // 发现的 POI
    let discoveredPOICount: Int         // 本次发现的 POI 数量
    let totalPOICount: Int              // 累计发现的 POI 数量

    /// 格式化本次行走距离
    var formattedWalkDistanceThisTime: String {
        if walkDistanceThisTime >= 1000 {
            return String(format: "%.2f km", walkDistanceThisTime / 1000)
        } else {
            return String(format: "%.0f m", walkDistanceThisTime)
        }
    }

    /// 格式化累计行走距离
    var formattedWalkDistanceTotal: String {
        if walkDistanceTotal >= 1000 {
            return String(format: "%.2f km", walkDistanceTotal / 1000)
        } else {
            return String(format: "%.0f m", walkDistanceTotal)
        }
    }

    /// 格式化探索时长
    var formattedDuration: String {
        let minutes = Int(explorationDuration) / 60
        let seconds = Int(explorationDuration) % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)小时\(mins)分钟"
        } else {
            return "\(minutes)分\(seconds)秒"
        }
    }
}

/// 探索结果（单次探索的完整结果）
struct ExplorationResult: Codable {
    let id: UUID                        // 探索记录 ID
    let startTime: Date                 // 开始时间
    let endTime: Date                   // 结束时间
    let stats: ExplorationStats         // 统计数据
    let obtainedItems: [ObtainedItem]   // 获得的物品

    /// 获得的物品（简化版，用于结果展示）
    struct ObtainedItem: Codable {
        let itemId: String              // 物品 ID
        let quantity: Int               // 数量
        let quality: ItemQuality?       // 品质
    }
}

// MARK: - 测试假数据

/// 探索模块测试假数据
struct MockExplorationData {

    // MARK: - POI 假数据

    /// 测试用 POI 列表（5 个不同状态的兴趣点）
    static let mockPOIs: [POI] = [
        // 1. 废弃超市：已发现，有物资
        POI(
            id: UUID(),
            name: "废弃超市",
            type: .supermarket,
            coordinate: POI.Coordinate(latitude: 31.2345, longitude: 121.4567),
            status: .discovered,
            hasLoot: true,
            dangerLevel: 2,
            description: "一家被遗弃的大型超市，货架上还残留着一些物资，但要小心可能有其他幸存者。"
        ),

        // 2. 医院废墟：已发现，已被搜空
        POI(
            id: UUID(),
            name: "医院废墟",
            type: .hospital,
            coordinate: POI.Coordinate(latitude: 31.2367, longitude: 121.4589),
            status: .looted,
            hasLoot: false,
            dangerLevel: 4,
            description: "曾经繁忙的医院如今已成废墟，医疗物资早已被搜刮一空，只剩下破碎的玻璃和倒塌的病床。"
        ),

        // 3. 加油站：未发现
        POI(
            id: UUID(),
            name: "加油站",
            type: .gasStation,
            coordinate: POI.Coordinate(latitude: 31.2389, longitude: 121.4601),
            status: .undiscovered,
            hasLoot: true,
            dangerLevel: 3,
            description: "路边的一座加油站，可能还有燃料和便利店物资。"
        ),

        // 4. 药店废墟：已发现，有物资
        POI(
            id: UUID(),
            name: "药店废墟",
            type: .pharmacy,
            coordinate: POI.Coordinate(latitude: 31.2356, longitude: 121.4578),
            status: .discovered,
            hasLoot: true,
            dangerLevel: 2,
            description: "一家小型药店，虽然门窗破损，但里面可能还有一些急需的药品和医疗用品。"
        ),

        // 5. 工厂废墟：未发现
        POI(
            id: UUID(),
            name: "工厂废墟",
            type: .factory,
            coordinate: POI.Coordinate(latitude: 31.2401, longitude: 121.4623),
            status: .undiscovered,
            hasLoot: true,
            dangerLevel: 3,
            description: "郊区的一座废弃工厂，可能有大量工业材料和工具。"
        )
    ]

    // MARK: - 物品定义假数据

    /// 物品定义表（记录每种物品的基础属性）
    static let itemDefinitions: [String: ItemDefinition] = [
        // 水类
        "water_bottle": ItemDefinition(
            id: "water_bottle",
            name: "矿泉水",
            category: .water,
            weight: 0.5,
            volume: 0.5,
            rarity: .common,
            description: "一瓶密封的矿泉水，在末日世界中极为珍贵。",
            stackable: true,
            maxStack: 10,
            hasQuality: false
        ),

        // 食物
        "canned_food": ItemDefinition(
            id: "canned_food",
            name: "罐头食品",
            category: .food,
            weight: 0.4,
            volume: 0.3,
            rarity: .common,
            description: "保质期很长的罐头食品，可以提供基本的营养。",
            stackable: true,
            maxStack: 20,
            hasQuality: true
        ),

        // 医疗
        "bandage": ItemDefinition(
            id: "bandage",
            name: "绷带",
            category: .medical,
            weight: 0.05,
            volume: 0.02,
            rarity: .common,
            description: "基础的医疗绷带，可以处理轻微伤口。",
            stackable: true,
            maxStack: 50,
            hasQuality: false
        ),
        "medicine": ItemDefinition(
            id: "medicine",
            name: "药品",
            category: .medical,
            weight: 0.1,
            volume: 0.05,
            rarity: .uncommon,
            description: "通用药品，可以治疗常见疾病。",
            stackable: true,
            maxStack: 30,
            hasQuality: true
        ),

        // 材料
        "wood": ItemDefinition(
            id: "wood",
            name: "木材",
            category: .material,
            weight: 1.0,
            volume: 2.0,
            rarity: .common,
            description: "基础建筑材料，可用于建造和修复。",
            stackable: true,
            maxStack: 100,
            hasQuality: false
        ),
        "scrap_metal": ItemDefinition(
            id: "scrap_metal",
            name: "废金属",
            category: .material,
            weight: 0.8,
            volume: 0.5,
            rarity: .common,
            description: "从废墟中回收的金属碎片，可以熔炼再利用。",
            stackable: true,
            maxStack: 100,
            hasQuality: false
        ),

        // 工具
        "flashlight": ItemDefinition(
            id: "flashlight",
            name: "手电筒",
            category: .tool,
            weight: 0.3,
            volume: 0.2,
            rarity: .uncommon,
            description: "便携式手电筒，夜间探索的必备工具。",
            stackable: false,
            maxStack: 1,
            hasQuality: true
        ),
        "rope": ItemDefinition(
            id: "rope",
            name: "绳子",
            category: .tool,
            weight: 0.5,
            volume: 0.3,
            rarity: .common,
            description: "结实的尼龙绳，用途广泛。",
            stackable: true,
            maxStack: 10,
            hasQuality: false
        )
    ]

    // MARK: - 背包物品假数据

    /// 测试用背包物品（8 种不同类型的物品）
    static let mockInventoryItems: [InventoryItem] = [
        // 矿泉水 x3（无品质）
        InventoryItem(
            id: UUID(),
            itemId: "water_bottle",
            quantity: 3,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-3600)
        ),

        // 罐头食品 x5（良好品质）
        InventoryItem(
            id: UUID(),
            itemId: "canned_food",
            quantity: 5,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-7200)
        ),

        // 绷带 x10（无品质）
        InventoryItem(
            id: UUID(),
            itemId: "bandage",
            quantity: 10,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-1800)
        ),

        // 药品 x3（普通品质）
        InventoryItem(
            id: UUID(),
            itemId: "medicine",
            quantity: 3,
            quality: .normal,
            obtainedAt: Date().addingTimeInterval(-5400)
        ),

        // 木材 x15（无品质）
        InventoryItem(
            id: UUID(),
            itemId: "wood",
            quantity: 15,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-10800)
        ),

        // 废金属 x8（无品质）
        InventoryItem(
            id: UUID(),
            itemId: "scrap_metal",
            quantity: 8,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-14400)
        ),

        // 手电筒 x1（良好品质）
        InventoryItem(
            id: UUID(),
            itemId: "flashlight",
            quantity: 1,
            quality: .good,
            obtainedAt: Date().addingTimeInterval(-86400)
        ),

        // 绳子 x2（无品质）
        InventoryItem(
            id: UUID(),
            itemId: "rope",
            quantity: 2,
            quality: nil,
            obtainedAt: Date().addingTimeInterval(-43200)
        )
    ]

    // MARK: - 探索结果假数据

    /// 测试用探索结果（旧版本，保留兼容）
    static let mockExplorationResult: ExplorationResult = ExplorationResult(
        id: UUID(),
        startTime: Date().addingTimeInterval(-1800),  // 30分钟前开始
        endTime: Date(),                               // 刚刚结束
        stats: ExplorationStats(
            walkDistanceThisTime: 2500,               // 本次 2500 米
            walkDistanceTotal: 15000,                 // 累计 15000 米
            walkDistanceRank: 42,                     // 排名 42
            explorationDuration: 1800,                // 30 分钟
            discoveredPOICount: 2,                    // 本次发现 2 个 POI
            totalPOICount: 15                         // 累计发现 15 个 POI
        ),
        obtainedItems: [
            // 木材 x5
            ExplorationResult.ObtainedItem(itemId: "wood", quantity: 5, quality: nil),
            // 矿泉水 x3
            ExplorationResult.ObtainedItem(itemId: "water_bottle", quantity: 3, quality: nil),
            // 罐头 x2（普通品质）
            ExplorationResult.ObtainedItem(itemId: "canned_food", quantity: 2, quality: .normal)
        ]
    )

    /// 测试用探索奖励结果（新版本，用于实际探索功能）
    static let mockExplorationRewardResult: ExplorationRewardResult = ExplorationRewardResult(
        sessionId: UUID(),
        distance: 2500,
        duration: 1800,
        rewardTier: .gold,
        rewardedItems: [
            ExplorationRewardResult.RewardedItem(
                itemId: "wood",
                name: "木材",
                quantity: 5,
                rarity: "common",
                icon: "cube.fill",
                category: "material"
            ),
            ExplorationRewardResult.RewardedItem(
                itemId: "water_bottle",
                name: "矿泉水",
                quantity: 3,
                rarity: "common",
                icon: "drop.fill",
                category: "food"
            ),
            ExplorationRewardResult.RewardedItem(
                itemId: "medicine",
                name: "药品",
                quantity: 2,
                rarity: "rare",
                icon: "pills.fill",
                category: "medical"
            )
        ]
    )

    // MARK: - 辅助方法

    /// 根据物品 ID 获取物品定义
    /// - Parameter itemId: 物品 ID
    /// - Returns: 物品定义或 nil
    static func getItemDefinition(for itemId: String) -> ItemDefinition? {
        return itemDefinitions[itemId]
    }

    /// 获取背包物品的完整信息（包含定义和实例）
    /// - Parameter item: 背包物品
    /// - Returns: (物品定义, 背包物品) 元组或 nil
    static func getFullItemInfo(for item: InventoryItem) -> (definition: ItemDefinition, instance: InventoryItem)? {
        guard let definition = itemDefinitions[item.itemId] else { return nil }
        return (definition, item)
    }

    /// 计算背包总重量
    /// - Parameter items: 背包物品列表
    /// - Returns: 总重量（kg）
    static func calculateTotalWeight(items: [InventoryItem]) -> Double {
        var totalWeight: Double = 0
        for item in items {
            if let definition = itemDefinitions[item.itemId] {
                totalWeight += definition.weight * Double(item.quantity)
            }
        }
        return totalWeight
    }

    /// 计算背包总体积
    /// - Parameter items: 背包物品列表
    /// - Returns: 总体积（L）
    static func calculateTotalVolume(items: [InventoryItem]) -> Double {
        var totalVolume: Double = 0
        for item in items {
            if let definition = itemDefinitions[item.itemId] {
                totalVolume += definition.volume * Double(item.quantity)
            }
        }
        return totalVolume
    }
}
