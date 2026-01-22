//
//  InventoryManager.swift
//  EarthLord day7
//
//  背包管理器
//  负责背包数据加载、物品增删改、与 Supabase 同步
//

import Foundation
import Combine
import Supabase

/// 背包管理器
@MainActor
class InventoryManager: ObservableObject {

    // MARK: - 单例

    static let shared = InventoryManager()

    // MARK: - 发布的状态

    /// 背包物品列表（普通物品）
    @Published var inventoryItems: [DBInventoryItem] = []

    /// AI 背包物品列表
    @Published var aiInventoryItems: [DBAIInventoryItem] = []

    /// 物品定义缓存
    @Published var itemDefinitions: [String: DBItemDefinition] = [:]

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 初始化

    private init() {
        print("📦 InventoryManager 初始化")
    }

    // MARK: - 加载方法

    /// 加载物品定义
    func loadItemDefinitions() async {
        do {
            let items: [DBItemDefinition] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            itemDefinitions = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            print("📦 加载了 \(items.count) 个物品定义")
        } catch {
            errorMessage = "加载物品定义失败"
            print("❌ 加载物品定义失败: \(error)")
        }
    }

    /// 加载用户背包（包括普通物品和 AI 物品）
    func loadInventory() async {
        guard let userId = await getCurrentUserId() else {
            errorMessage = "未登录"
            print("❌ 加载背包失败：未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        // 确保物品定义已加载
        if itemDefinitions.isEmpty {
            await loadItemDefinitions()
        }

        do {
            // 加载普通物品
            let items: [DBInventoryItem] = try await supabase
                .from("inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            inventoryItems = items
            print("📦 加载了 \(items.count) 个普通背包物品")

            // 同时加载 AI 物品
            await loadAIInventory()
        } catch {
            errorMessage = "加载背包失败"
            print("❌ 加载背包失败: \(error)")
        }

        isLoading = false
    }

    /// 加载 AI 生成的物品
    func loadAIInventory() async {
        guard let userId = await getCurrentUserId() else {
            print("❌ 加载AI背包失败：未登录")
            return
        }

        do {
            let items: [DBAIInventoryItem] = try await supabase
                .from("ai_inventory_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("obtained_at", ascending: false)
                .execute()
                .value

            aiInventoryItems = items
            print("📦 加载了 \(items.count) 个 AI 背包物品")
        } catch {
            print("❌ 加载AI背包失败: \(error)")
        }
    }

    /// 添加物品到背包（支持堆叠）
    func addItems(_ items: [(itemId: String, quantity: Int)]) async {
        guard let userId = await getCurrentUserId() else {
            print("❌ 添加物品失败：未登录")
            return
        }

        for item in items {
            // 检查是否已有该物品（堆叠）
            if let existingIndex = inventoryItems.firstIndex(where: { $0.itemId == item.itemId }) {
                // 更新数量
                let existingItem = inventoryItems[existingIndex]
                let newQuantity = existingItem.quantity + item.quantity

                do {
                    let updateData = DBInventoryItemUpdate(quantity: newQuantity)
                    try await supabase
                        .from("inventory_items")
                        .update(updateData)
                        .eq("id", value: existingItem.id.uuidString)
                        .execute()

                    inventoryItems[existingIndex].quantity = newQuantity
                    print("📦 物品堆叠: \(item.itemId) +\(item.quantity) = \(newQuantity)")
                } catch {
                    print("❌ 更新物品数量失败: \(error)")
                }
            } else {
                // 插入新物品
                let newItem = DBInventoryItemInsert(
                    userId: userId,
                    itemId: item.itemId,
                    quantity: item.quantity
                )

                do {
                    let inserted: DBInventoryItem = try await supabase
                        .from("inventory_items")
                        .insert(newItem)
                        .select()
                        .single()
                        .execute()
                        .value

                    inventoryItems.insert(inserted, at: 0)
                    print("📦 新增物品: \(item.itemId) x\(item.quantity)")
                } catch {
                    print("❌ 插入物品失败: \(error)")
                }
            }
        }
    }

    /// 使用物品（减少数量）
    func useItem(itemId: UUID, amount: Int = 1) async -> Bool {
        guard let index = inventoryItems.firstIndex(where: { $0.id == itemId }) else {
            print("❌ 物品不存在")
            return false
        }

        let item = inventoryItems[index]
        let newQuantity = item.quantity - amount

        if newQuantity <= 0 {
            // 删除物品
            do {
                try await supabase
                    .from("inventory_items")
                    .delete()
                    .eq("id", value: itemId.uuidString)
                    .execute()

                inventoryItems.remove(at: index)
                print("📦 物品用尽删除: \(item.itemId)")
                return true
            } catch {
                print("❌ 删除物品失败: \(error)")
                return false
            }
        } else {
            // 更新数量
            do {
                let updateData = DBInventoryItemUpdate(quantity: newQuantity)
                try await supabase
                    .from("inventory_items")
                    .update(updateData)
                    .eq("id", value: itemId.uuidString)
                    .execute()

                inventoryItems[index].quantity = newQuantity
                print("📦 使用物品: \(item.itemId) -\(amount) = \(newQuantity)")
                return true
            } catch {
                print("❌ 更新物品数量失败: \(error)")
                return false
            }
        }
    }

    /// 获取物品定义
    func getDefinition(for itemId: String) -> DBItemDefinition? {
        return itemDefinitions[itemId]
    }

    /// 计算背包总重量（普通物品 + AI物品）
    var totalWeight: Double {
        // 普通物品重量
        let normalWeight = inventoryItems.reduce(0) { total, item in
            let weight = itemDefinitions[item.itemId]?.weight ?? 0
            return total + weight * Double(item.quantity)
        }
        // AI物品重量（根据类别估算）
        let aiWeight = aiInventoryItems.reduce(0) { total, item in
            let weight = estimateAIItemWeight(category: item.category)
            return total + weight * Double(item.quantity)
        }
        return normalWeight + aiWeight
    }

    /// 根据类别估算AI物品重量
    private func estimateAIItemWeight(category: String) -> Double {
        switch category {
        case "food": return 0.3      // 食物 0.3kg
        case "medical": return 0.2   // 医疗 0.2kg
        case "tool": return 0.5      // 工具 0.5kg
        case "material": return 0.4  // 材料 0.4kg
        case "equipment": return 0.8 // 装备 0.8kg
        case "water": return 0.5     // 水类 0.5kg
        case "weapon": return 1.0    // 武器 1.0kg
        default: return 0.3          // 默认 0.3kg
        }
    }

    /// 物品总数（不同种类数，包括 AI 物品）
    var itemTypeCount: Int {
        inventoryItems.count + aiInventoryItems.count
    }

    /// 物品总数量（所有数量之和，包括 AI 物品）
    var totalItemCount: Int {
        let normalCount = inventoryItems.reduce(0) { $0 + $1.quantity }
        let aiCount = aiInventoryItems.reduce(0) { $0 + $1.quantity }
        return normalCount + aiCount
    }

    /// AI 物品数量
    var aiItemCount: Int {
        aiInventoryItems.count
    }

    /// 使用 AI 物品（减少数量或删除）
    func useAIItem(itemId: UUID, amount: Int = 1) async -> Bool {
        guard let index = aiInventoryItems.firstIndex(where: { $0.id == itemId }) else {
            print("❌ AI物品不存在")
            return false
        }

        let item = aiInventoryItems[index]
        let newQuantity = item.quantity - amount

        if newQuantity <= 0 {
            // 删除物品
            do {
                try await supabase
                    .from("ai_inventory_items")
                    .delete()
                    .eq("id", value: itemId.uuidString)
                    .execute()

                aiInventoryItems.remove(at: index)
                print("📦 AI物品用尽删除: \(item.name)")
                return true
            } catch {
                print("❌ 删除AI物品失败: \(error)")
                return false
            }
        } else {
            // 更新数量
            do {
                try await supabase
                    .from("ai_inventory_items")
                    .update(["quantity": newQuantity])
                    .eq("id", value: itemId.uuidString)
                    .execute()

                // 需要重新加载因为 DBAIInventoryItem 的 quantity 是 let
                await loadAIInventory()
                print("📦 使用AI物品: \(item.name) -\(amount) = \(newQuantity)")
                return true
            } catch {
                print("❌ 更新AI物品数量失败: \(error)")
                return false
            }
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
