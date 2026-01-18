//
//  AIItemGenerator.swift
//  EarthLord day7
//
//  AI 物品生成器
//  负责调用 Edge Function 生成独特物品并保存到数据库
//

import Foundation
import Supabase

/// AI 物品生成请求体
private struct AIItemGenerationRequest: Encodable {
    let poiName: String
    let poiType: String
    let dangerLevel: Int
    let count: Int
}

/// AI 物品生成器
@MainActor
final class AIItemGenerator {

    // MARK: - 单例

    static let shared = AIItemGenerator()

    // MARK: - 私有属性

    /// 请求超时时间（秒）
    private let requestTimeout: TimeInterval = 10.0

    // MARK: - 初始化

    private init() {
        print("🤖 AIItemGenerator 初始化")
    }

    // MARK: - 公开方法

    /// 为 POI 生成 AI 物品
    /// - Parameters:
    ///   - poi: 兴趣点
    ///   - count: 生成数量（默认3个）
    /// - Returns: 生成的物品列表，失败返回 nil
    func generateItems(for poi: POI, count: Int = 3) async -> [AIGeneratedItem]? {
        print("🤖 [AI] 开始为 \(poi.name) 生成 \(count) 个物品")
        TerritoryLogger.shared.log("AI 正在生成物品...", type: .info)

        let requestBody = AIItemGenerationRequest(
            poiName: poi.name,
            poiType: poi.typeDisplayName,
            dangerLevel: poi.dangerLevel,
            count: count
        )

        do {
            // 调用 Edge Function
            let response: AIItemGenerationResponse = try await supabase.functions
                .invoke(
                    "generate-ai-item",
                    options: FunctionInvokeOptions(body: requestBody)
                )

            if response.success, let items = response.items {
                print("🤖 [AI] 成功生成 \(items.count) 个物品")
                TerritoryLogger.shared.log("AI 生成了 \(items.count) 个独特物品", type: .success)
                return items
            } else {
                print("❌ [AI] 生成失败: \(response.error ?? "未知错误")")
                TerritoryLogger.shared.log("AI 生成失败，使用预设物品", type: .warning)
                return nil
            }

        } catch {
            print("❌ [AI] 调用失败: \(error)")
            TerritoryLogger.shared.log("AI 服务不可用，使用预设物品", type: .warning)
            return nil
        }
    }

    /// 保存 AI 物品到数据库
    /// - Parameters:
    ///   - items: AI 生成的物品列表
    ///   - poi: 来源 POI
    /// - Returns: 保存的物品列表
    func saveToInventory(items: [AIGeneratedItem], poi: POI) async -> [DBAIInventoryItem] {
        guard let userId = await getCurrentUserId() else {
            print("❌ [AI] 保存失败：未登录")
            return []
        }

        var savedItems: [DBAIInventoryItem] = []

        for item in items {
            let insertItem = DBAIInventoryItemInsert(
                userId: userId,
                name: item.name,
                category: item.category,
                rarity: item.rarity,
                icon: item.icon,
                story: item.story,
                quantity: 1,
                poiName: poi.name
            )

            do {
                let saved: DBAIInventoryItem = try await supabase
                    .from("ai_inventory_items")
                    .insert(insertItem)
                    .select()
                    .single()
                    .execute()
                    .value

                savedItems.append(saved)
                print("🤖 [AI] 保存物品: \(item.name)")
            } catch {
                print("❌ [AI] 保存物品失败: \(error)")
            }
        }

        print("🤖 [AI] 共保存 \(savedItems.count) 个物品到背包")
        return savedItems
    }

    /// 生成降级方案物品（当 AI 服务不可用时）
    /// - Parameters:
    ///   - poi: 兴趣点
    ///   - count: 生成数量
    /// - Returns: 预设物品列表
    func generateFallbackItems(for poi: POI, count: Int) -> [AIGeneratedItem] {
        print("🤖 [AI] 使用降级方案生成物品")

        // 预设物品库（按 POI 类型分类）
        let presetItems: [POIType: [(name: String, category: String, story: String)]] = [
            .hospital: [
                ("急救绷带", "medical", "医院储藏室里找到的标准医疗用品"),
                ("止痛药片", "medical", "护士站抽屉里的常备药物"),
                ("消毒酒精", "medical", "手术室遗留的消毒用品"),
                ("医用手套", "medical", "储物柜里的一次性手套"),
                ("生理盐水", "medical", "输液架上残留的盐水袋")
            ],
            .pharmacy: [
                ("感冒胶囊", "medical", "药店货架上的常见药物"),
                ("维生素片", "medical", "保健品区找到的营养补充剂"),
                ("创可贴", "medical", "收银台旁的小药箱里"),
                ("退烧贴", "medical", "儿童区货架上的退烧用品"),
                ("碘伏药水", "medical", "消毒用品区的碘伏溶液")
            ],
            .supermarket: [
                ("罐头食品", "food", "货架角落里被遗忘的罐头"),
                ("矿泉水瓶", "water", "还算干净的瓶装水"),
                ("压缩饼干", "food", "收银台后的应急食品"),
                ("方便面袋", "food", "货架深处的速食面"),
                ("巧克力棒", "food", "糖果区剩余的能量棒")
            ],
            .gasStation: [
                ("防冻液", "material", "货架上的汽车用品"),
                ("工具扳手", "tool", "维修区的常用工具"),
                ("手电筒", "tool", "收银台抽屉里的应急用品"),
                ("打火机", "tool", "柜台上的廉价打火机"),
                ("绝缘胶带", "material", "杂货区的修理用品")
            ],
            .police: [
                ("战术手套", "equipment", "装备室里的防护手套"),
                ("警用手电", "tool", "值班室的照明工具"),
                ("急救包", "medical", "巡逻车里的医疗包"),
                ("防刺背心", "equipment", "储物柜里的防护装备"),
                ("通讯电池", "material", "通讯室的备用电池")
            ],
            .military: [
                ("军用口粮", "food", "仓库里的压缩食品"),
                ("战术绷带", "medical", "战地医疗包里的绷带"),
                ("多功能刀", "tool", "士兵个人装备"),
                ("夜视镜片", "equipment", "光学设备零件"),
                ("军用水壶", "water", "标准军用饮水器具")
            ],
            .warehouse: [
                ("包装绳索", "material", "打包区的捆扎绳"),
                ("防护手套", "equipment", "工人储物柜的手套"),
                ("铁丝卷", "material", "杂物堆里的铁丝"),
                ("塑料布", "material", "遮盖货物用的塑料布"),
                ("标签纸", "material", "办公区的文具用品")
            ],
            .factory: [
                ("机械零件", "material", "生产线上的零部件"),
                ("工业手套", "equipment", "车间的劳保用品"),
                ("润滑油", "material", "机器维护用的润滑油"),
                ("螺丝刀", "tool", "维修工具箱的工具"),
                ("电线卷", "material", "电气维修区的电线")
            ],
            .house: [
                ("家用药品", "medical", "药箱里的常备药"),
                ("瓶装饮料", "water", "冰箱里的饮料瓶"),
                ("饼干零食", "food", "橱柜里的零食"),
                ("手电筒", "tool", "抽屉里的应急用品"),
                ("厨房刀具", "tool", "厨房的常用刀具")
            ]
        ]

        // 获取对应类型的预设物品
        let typeItems = presetItems[poi.type] ?? presetItems[.house]!

        // 根据危险等级确定稀有度分布
        let rarities = (0..<count).map { _ in selectRarityByDanger(poi.dangerLevel) }

        // 随机选择物品
        var result: [AIGeneratedItem] = []
        for i in 0..<min(count, typeItems.count) {
            let preset = typeItems.randomElement()!
            result.append(AIGeneratedItem(
                name: preset.name,
                category: preset.category,
                rarity: rarities[i],
                icon: getIconForCategory(preset.category),
                story: preset.story
            ))
        }

        return result
    }

    // MARK: - 私有方法

    /// 根据危险等级选择稀有度
    private func selectRarityByDanger(_ dangerLevel: Int) -> String {
        let random = Double.random(in: 0..<1)

        switch dangerLevel {
        case 1, 2:
            // 低危: common 70%, uncommon 25%, rare 5%
            if random < 0.70 { return "common" }
            if random < 0.95 { return "uncommon" }
            return "rare"

        case 3:
            // 中危: common 50%, uncommon 30%, rare 15%, epic 5%
            if random < 0.50 { return "common" }
            if random < 0.80 { return "uncommon" }
            if random < 0.95 { return "rare" }
            return "epic"

        case 4:
            // 高危: uncommon 40%, rare 35%, epic 20%, legendary 5%
            if random < 0.40 { return "uncommon" }
            if random < 0.75 { return "rare" }
            if random < 0.95 { return "epic" }
            return "legendary"

        case 5:
            // 极危: rare 30%, epic 40%, legendary 30%
            if random < 0.30 { return "rare" }
            if random < 0.70 { return "epic" }
            return "legendary"

        default:
            return "common"
        }
    }

    /// 根据分类获取图标
    private func getIconForCategory(_ category: String) -> String {
        switch category {
        case "food": return "fork.knife"
        case "medical": return "cross.case.fill"
        case "tool": return "wrench.and.screwdriver.fill"
        case "material": return "cube.fill"
        case "equipment": return "shield.fill"
        case "water": return "drop.fill"
        case "weapon": return "bolt.fill"
        default: return "questionmark.circle.fill"
        }
    }

    /// 获取当前用户 ID
    private func getCurrentUserId() async -> UUID? {
        do {
            let session = try await supabase.auth.session
            return session.user.id
        } catch {
            print("❌ 获取用户ID失败: \(error)")
            return nil
        }
    }
}
