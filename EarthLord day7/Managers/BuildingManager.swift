//
//  BuildingManager.swift
//  EarthLord day7
//
//  建筑管理器
//  负责建筑模板加载、建造检查、建筑创建与升级
//

import Foundation
import Combine
import Supabase

// MARK: - 建筑通知

extension Notification.Name {
    /// 建筑数据更新通知
    static let buildingUpdated = Notification.Name("buildingUpdated")
}

/// 建筑管理器
@MainActor
class BuildingManager: ObservableObject {

    // MARK: - 单例

    static let shared = BuildingManager()

    // MARK: - 发布的状态

    /// 建筑模板列表
    @Published var buildingTemplates: [BuildingTemplate] = []

    /// 玩家建筑列表
    @Published var playerBuildings: [PlayerBuilding] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 初始化

    private init() {
        print("🏗️ BuildingManager 初始化")
    }

    // MARK: - 模板加载

    /// 从 JSON 文件加载建筑模板
    func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            print("❌ 找不到 building_templates.json 文件")
            errorMessage = "找不到建筑模板文件"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let templateList = try decoder.decode(BuildingTemplateList.self, from: data)
            buildingTemplates = templateList.templates
            print("✅ 成功加载 \(buildingTemplates.count) 个建筑模板")
        } catch {
            print("❌ 解析建筑模板失败: \(error)")
            errorMessage = "解析建筑模板失败"
        }
    }

    /// 根据 templateId 获取模板
    func getTemplate(for templateId: String) -> BuildingTemplate? {
        return buildingTemplates.first { $0.templateId == templateId }
    }

    /// 按分类获取模板
    func getTemplates(for category: BuildingCategory) -> [BuildingTemplate] {
        return buildingTemplates.filter { $0.category == category.rawValue }
    }

    // MARK: - 建造检查

    /// 检查是否可以建造
    /// - Parameters:
    ///   - template: 建筑模板
    ///   - territoryId: 领地 ID
    /// - Returns: 建造检查结果
    func canBuild(template: BuildingTemplate, territoryId: String) async -> BuildCheckResult {
        // 1. 检查该类型建筑在领地内的数量
        let currentCount = playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == template.templateId
        }.count

        if currentCount >= template.maxPerTerritory {
            return .maxReached(currentCount: currentCount, maxCount: template.maxPerTerritory)
        }

        // 2. 检查资源是否足够
        let missingResources = checkResources(required: template.requiredResources)

        if !missingResources.isEmpty {
            return .insufficientResources(missingResources, currentCount: currentCount, maxCount: template.maxPerTerritory)
        }

        return .success(currentCount: currentCount, maxCount: template.maxPerTerritory)
    }

    /// 检查资源是否足够
    /// - Parameter required: 所需资源 [资源名: 数量]
    /// - Returns: 缺少的资源 [资源名: 缺少数量]，空表示资源足够
    private func checkResources(required: [String: Int]) -> [String: Int] {
        var missing: [String: Int] = [:]
        let inventory = InventoryManager.shared

        for (resourceName, requiredAmount) in required {
            let ownedAmount = getResourceAmount(resourceName: resourceName, inventory: inventory)
            if ownedAmount < requiredAmount {
                missing[resourceName] = requiredAmount - ownedAmount
            }
        }

        return missing
    }

    /// 获取玩家拥有的资源数量
    /// - Parameters:
    ///   - resourceName: 资源名称（如 wood, stone, metal, glass）
    ///   - inventory: 背包管理器
    /// - Returns: 拥有的数量
    private func getResourceAmount(resourceName: String, inventory: InventoryManager) -> Int {
        // 先检查普通物品（itemId 匹配）
        if let item = inventory.inventoryItems.first(where: { $0.itemId == resourceName }) {
            return item.quantity
        }

        // 再检查 AI 物品（name 匹配，不区分大小写）
        let lowercaseName = resourceName.lowercased()
        let aiItem = inventory.aiInventoryItems.first { item in
            item.name.lowercased() == lowercaseName ||
            item.name.lowercased().contains(lowercaseName)
        }

        return aiItem?.quantity ?? 0
    }

    // MARK: - 建造操作

    /// 开始建造建筑
    /// - Parameters:
    ///   - templateId: 建筑模板 ID
    ///   - territoryId: 领地 ID
    ///   - location: 建筑位置 (纬度, 经度)
    /// - Returns: 创建的建筑
    func startConstruction(
        templateId: String,
        territoryId: String,
        location: (lat: Double, lon: Double)?
    ) async throws -> PlayerBuilding {
        // 1. 获取模板
        guard let template = getTemplate(for: templateId) else {
            throw BuildingError.templateNotFound
        }

        // 2. 检查是否可以建造
        let checkResult = await canBuild(template: template, territoryId: territoryId)
        if !checkResult.canBuild {
            if !checkResult.missingResources.isEmpty {
                throw BuildingError.insufficientResources(checkResult.missingResources)
            } else {
                throw BuildingError.maxBuildingsReached(checkResult.maxCount)
            }
        }

        // 3. 扣除资源
        await deductResources(required: template.requiredResources)

        // 4. 获取用户 ID
        guard let userId = await getCurrentUserId() else {
            throw BuildingError.databaseError("未登录")
        }

        // 5. 计算建造完成时间
        let completedAt = Date().addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        // 6. 创建建筑记录
        let newBuilding = PlayerBuildingInsert(
            userId: userId,
            territoryId: territoryId,
            templateId: templateId,
            buildingName: template.localizedName,
            status: BuildingStatus.constructing.rawValue,
            level: 1,
            locationLat: location?.lat,
            locationLon: location?.lon,
            buildCompletedAt: completedAt
        )

        do {
            let inserted: PlayerBuilding = try await supabase
                .from("player_buildings")
                .insert(newBuilding)
                .select()
                .single()
                .execute()
                .value

            playerBuildings.insert(inserted, at: 0)
            print("🏗️ 开始建造: \(template.localizedName)")
            return inserted
        } catch {
            print("❌ 创建建筑失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    /// 扣除资源
    private func deductResources(required: [String: Int]) async {
        let inventory = InventoryManager.shared

        for (resourceName, amount) in required {
            // 先尝试从普通物品扣除
            if let item = inventory.inventoryItems.first(where: { $0.itemId == resourceName }) {
                _ = await inventory.useItem(itemId: item.id, amount: amount)
                continue
            }

            // 再尝试从 AI 物品扣除
            let lowercaseName = resourceName.lowercased()
            if let aiItem = inventory.aiInventoryItems.first(where: {
                $0.name.lowercased() == lowercaseName ||
                $0.name.lowercased().contains(lowercaseName)
            }) {
                _ = await inventory.useAIItem(itemId: aiItem.id, amount: amount)
            }
        }
    }

    /// 完成建造（更新状态为 active）
    /// - Parameter buildingId: 建筑 ID
    func completeConstruction(buildingId: UUID) async throws {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.databaseError("建筑不存在")
        }

        let building = playerBuildings[index]

        // 检查是否已经完成建造时间
        if !building.isConstructionComplete {
            print("⏳ 建筑尚未完成建造")
            return
        }

        // 更新状态
        let updateData = PlayerBuildingUpdate(status: BuildingStatus.active.rawValue)

        do {
            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings[index].status = BuildingStatus.active.rawValue
            print("✅ 建筑完成: \(building.buildingName)")
        } catch {
            print("❌ 更新建筑状态失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    /// 升级建筑
    /// - Parameter buildingId: 建筑 ID
    func upgradeBuilding(buildingId: UUID) async throws {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.databaseError("建筑不存在")
        }

        let building = playerBuildings[index]

        // 检查状态必须是 active
        if building.statusEnum != .active {
            throw BuildingError.invalidStatus
        }

        // 获取模板检查最大等级
        guard let template = getTemplate(for: building.templateId) else {
            throw BuildingError.templateNotFound
        }

        if building.level >= template.maxLevel {
            throw BuildingError.maxLevelReached
        }

        // 计算升级所需资源（基础资源 * 当前等级）
        var upgradeResources: [String: Int] = [:]
        for (resource, amount) in template.requiredResources {
            upgradeResources[resource] = amount * building.level
        }

        // 检查资源
        let missingResources = checkResources(required: upgradeResources)
        if !missingResources.isEmpty {
            throw BuildingError.insufficientResources(missingResources)
        }

        // 扣除资源
        await deductResources(required: upgradeResources)

        // 更新等级
        let newLevel = building.level + 1
        let updateData = PlayerBuildingUpdate(level: newLevel)

        do {
            try await supabase
                .from("player_buildings")
                .update(updateData)
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings[index].level = newLevel
            print("⬆️ 建筑升级: \(building.buildingName) -> Lv.\(newLevel)")
        } catch {
            print("❌ 升级建筑失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - 数据加载

    /// 获取玩家在指定领地内的建筑
    /// - Parameter territoryId: 领地 ID（可选，nil 表示获取所有）
    func fetchPlayerBuildings(territoryId: String? = nil) async {
        guard let userId = await getCurrentUserId() else {
            print("❌ 获取建筑失败：未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            var query = supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString)

            if let territoryId = territoryId {
                query = query.eq("territory_id", value: territoryId)
            }

            let buildings: [PlayerBuilding] = try await query
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = buildings
            print("🏗️ 加载了 \(buildings.count) 个建筑")

            // 检查并更新已完成建造的建筑状态
            await checkAndCompleteConstructions()
        } catch {
            errorMessage = "加载建筑失败"
            print("❌ 加载建筑失败: \(error)")
        }

        isLoading = false
    }

    /// 检查并完成已到期的建造
    private func checkAndCompleteConstructions() async {
        for building in playerBuildings {
            if building.statusEnum == .constructing && building.isConstructionComplete {
                try? await completeConstruction(buildingId: building.id)
            }
        }
    }

    /// 获取指定模板在领地内的建筑数量
    func getBuildingCount(templateId: String, territoryId: String) -> Int {
        return playerBuildings.filter {
            $0.territoryId == territoryId && $0.templateId == templateId
        }.count
    }

    // MARK: - 拆除操作

    /// 拆除建筑
    /// - Parameter buildingId: 建筑 ID
    func demolishBuilding(buildingId: UUID) async throws {
        guard let index = playerBuildings.firstIndex(where: { $0.id == buildingId }) else {
            throw BuildingError.databaseError("建筑不存在")
        }

        let building = playerBuildings[index]

        do {
            try await supabase
                .from("player_buildings")
                .delete()
                .eq("id", value: buildingId.uuidString)
                .execute()

            playerBuildings.remove(at: index)
            print("🗑️ 建筑已拆除: \(building.buildingName)")

            // 发送建筑更新通知
            NotificationCenter.default.post(name: .buildingUpdated, object: nil)
        } catch {
            print("❌ 拆除建筑失败: \(error)")
            throw BuildingError.databaseError(error.localizedDescription)
        }
    }

    // MARK: - 辅助方法

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
