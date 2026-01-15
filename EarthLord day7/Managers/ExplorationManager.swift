//
//  ExplorationManager.swift
//  EarthLord day7
//
//  探索管理器
//  负责探索会话管理、GPS追踪、奖励生成、数据库交互
//

import Foundation
import CoreLocation
import Combine
import Supabase

/// 探索管理器
@MainActor
class ExplorationManager: ObservableObject {

    // MARK: - 单例

    static let shared = ExplorationManager()

    // MARK: - 发布的状态

    /// 是否正在探索
    @Published var isExploring: Bool = false

    /// 当前探索会话 ID
    @Published var currentSessionId: UUID?

    /// 实时探索距离
    @Published var currentDistance: Double = 0

    /// 实时探索时长
    @Published var currentDuration: TimeInterval = 0

    /// 探索结果（结束时设置）
    @Published var explorationResult: ExplorationRewardResult?

    /// 错误信息
    @Published var errorMessage: String?

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 是否显示结果页面
    @Published var showResult: Bool = false

    /// 探索是否因超速失败
    @Published var explorationFailed: Bool = false

    /// 失败原因
    @Published var failureReason: String?

    // MARK: - 私有属性

    private var locationManager = LocationManager.shared
    private var inventoryManager = InventoryManager.shared
    private var durationTimer: Timer?
    private var itemDefinitionsCache: [String: DBItemDefinition] = [:]

    /// 超速通知监听器
    private var overSpeedObserver: NSObjectProtocol?

    // MARK: - 初始化

    private init() {
        print("🔍 ExplorationManager 初始化")
    }

    // MARK: - 公开方法

    /// 开始探索
    func startExploration() async -> Bool {
        guard !isExploring else {
            print("⚠️ 探索已在进行中")
            return false
        }

        isLoading = true
        errorMessage = nil

        // 1. 获取用户 ID
        guard let userId = await getCurrentUserId() else {
            errorMessage = "未登录"
            isLoading = false
            return false
        }

        // 2. 确保物品定义已加载
        if itemDefinitionsCache.isEmpty {
            await loadItemDefinitions()
        }

        // 3. 创建探索会话记录
        let startCoord = locationManager.userLocation
        let sessionInsert = DBExplorationSessionInsert(
            userId: userId,
            startLat: startCoord?.latitude,
            startLng: startCoord?.longitude,
            status: "active"
        )

        do {
            let session: DBExplorationSession = try await supabase
                .from("exploration_sessions")
                .insert(sessionInsert)
                .select()
                .single()
                .execute()
                .value

            currentSessionId = session.id

            // 4. 开始 GPS 追踪
            locationManager.startExplorationTracking()

            // 5. 启动时长计时器
            startDurationTimer()

            // 6. 监听超速超时通知
            overSpeedObserver = NotificationCenter.default.addObserver(
                forName: .explorationOverSpeedTimeout,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.handleOverSpeedFailure()
                }
            }

            isExploring = true
            isLoading = false

            print("🔍 [探索] 开始探索，会话ID: \(session.id)")
            TerritoryLogger.shared.log("探索会话开始", type: .success)
            return true

        } catch {
            errorMessage = "创建探索会话失败: \(error.localizedDescription)"
            isLoading = false
            print("❌ [探索] 创建会话失败: \(error)")
            TerritoryLogger.shared.log("探索创建失败: \(error.localizedDescription)", type: .error)
            return false
        }
    }

    /// 结束探索并计算奖励
    func endExploration() async -> ExplorationRewardResult? {
        guard isExploring, let sessionId = currentSessionId else {
            print("⚠️ 没有进行中的探索")
            return nil
        }

        isLoading = true

        // 移除超速监听器
        if let observer = overSpeedObserver {
            NotificationCenter.default.removeObserver(observer)
            overSpeedObserver = nil
        }

        // 1. 停止 GPS 追踪
        let (distance, duration) = locationManager.stopExplorationTracking()
        stopDurationTimer()

        // 2. 计算奖励等级
        let rewardTier = RewardTier.from(distance: distance)

        // 3. 生成奖励物品
        let rewardedItems = generateRewardItems(tier: rewardTier)

        // 4. 更新探索会话记录
        let endCoord = locationManager.explorationEndCoordinate
        let itemsRewardedJSON = encodeItemsToJSON(rewardedItems)

        let sessionUpdate = DBExplorationSessionUpdate(
            endTime: Date(),
            duration: Int(duration),
            totalDistance: distance,
            endLat: endCoord?.latitude,
            endLng: endCoord?.longitude,
            rewardTier: rewardTier.rawValue,
            itemsRewarded: itemsRewardedJSON,
            status: "completed"
        )

        do {
            try await supabase
                .from("exploration_sessions")
                .update(sessionUpdate)
                .eq("id", value: sessionId.uuidString)
                .execute()

            // 5. 将物品添加到背包
            if !rewardedItems.isEmpty {
                await inventoryManager.addItems(rewardedItems)
            }

            // 6. 构建结果
            let result = ExplorationRewardResult(
                sessionId: sessionId,
                distance: distance,
                duration: duration,
                rewardTier: rewardTier,
                rewardedItems: rewardedItems.map { item in
                    let def = itemDefinitionsCache[item.itemId]
                    return ExplorationRewardResult.RewardedItem(
                        itemId: item.itemId,
                        name: def?.name ?? item.itemId,
                        quantity: item.quantity,
                        rarity: def?.rarity ?? "common",
                        icon: def?.icon ?? "questionmark",
                        category: def?.category ?? "misc"
                    )
                }
            )

            explorationResult = result
            isExploring = false
            currentSessionId = nil
            isLoading = false
            showResult = true

            print("🔍 [探索] 结束，等级: \(rewardTier.displayName)，获得 \(rewardedItems.count) 种物品")
            TerritoryLogger.shared.log("探索完成: \(String(format: "%.0f", distance))m，等级: \(rewardTier.displayName)", type: .success)
            if !rewardedItems.isEmpty {
                TerritoryLogger.shared.log("探索奖励: \(rewardedItems.count)种物品", type: .success)
            }
            return result

        } catch {
            errorMessage = "保存探索结果失败: \(error.localizedDescription)"
            isLoading = false
            print("❌ 保存探索结果失败: \(error)")
            return nil
        }
    }

    /// 取消探索（不计算奖励）
    func cancelExploration() async {
        guard isExploring, let sessionId = currentSessionId else { return }

        // 移除超速监听器
        if let observer = overSpeedObserver {
            NotificationCenter.default.removeObserver(observer)
            overSpeedObserver = nil
        }

        let _ = locationManager.stopExplorationTracking()
        stopDurationTimer()

        // 更新状态为 cancelled
        let sessionUpdate = DBExplorationSessionUpdate(
            endTime: Date(),
            duration: nil,
            totalDistance: nil,
            endLat: nil,
            endLng: nil,
            rewardTier: nil,
            itemsRewarded: nil,
            status: "cancelled"
        )

        _ = try? await supabase
            .from("exploration_sessions")
            .update(sessionUpdate)
            .eq("id", value: sessionId.uuidString)
            .execute()

        isExploring = false
        currentSessionId = nil
        currentDistance = 0
        currentDuration = 0

        print("🔍 [探索] 已取消")
        TerritoryLogger.shared.log("探索已取消", type: .warning)
    }

    /// 重置结果状态
    func resetResult() {
        explorationResult = nil
        showResult = false
    }

    /// 重置失败状态
    func resetFailure() {
        explorationFailed = false
        failureReason = nil
    }

    // MARK: - 超速失败处理

    /// 处理超速失败
    private func handleOverSpeedFailure() async {
        guard isExploring, let sessionId = currentSessionId else { return }

        print("❌ [探索] 因超速停止探索")

        // 移除超速监听器
        if let observer = overSpeedObserver {
            NotificationCenter.default.removeObserver(observer)
            overSpeedObserver = nil
        }

        // 停止GPS追踪
        let _ = locationManager.stopExplorationTracking()
        stopDurationTimer()

        // 更新数据库状态为失败
        let sessionUpdate = DBExplorationSessionUpdate(
            endTime: Date(),
            duration: nil,
            totalDistance: nil,
            endLat: nil,
            endLng: nil,
            rewardTier: nil,
            itemsRewarded: nil,
            status: "failed_overspeed"
        )

        _ = try? await supabase
            .from("exploration_sessions")
            .update(sessionUpdate)
            .eq("id", value: sessionId.uuidString)
            .execute()

        // 设置失败状态
        explorationFailed = true
        failureReason = "移动速度过快，探索失败"
        isExploring = false
        currentSessionId = nil
        currentDistance = 0
        currentDuration = 0

        TerritoryLogger.shared.log("探索因超速失败", type: .error)
    }

    // MARK: - 奖励生成逻辑

    /// 生成奖励物品
    private func generateRewardItems(tier: RewardTier) -> [(itemId: String, quantity: Int)] {
        guard tier != .none else { return [] }

        let probabilities = tier.rarityProbabilities
        let itemCount = tier.itemCount

        var results: [(itemId: String, quantity: Int)] = []

        for _ in 0..<itemCount {
            // 1. 根据概率选择稀有度
            let rarity = selectRarity(probabilities: probabilities)

            // 2. 从对应稀有度的物品池中随机选择
            let itemsOfRarity = itemDefinitionsCache.values.filter { $0.rarity == rarity }
            guard let selectedItem = itemsOfRarity.randomElement() else { continue }

            // 3. 随机数量（1-3个）
            let quantity = Int.random(in: 1...3)

            results.append((itemId: selectedItem.id, quantity: quantity))
        }

        return results
    }

    /// 根据概率分布选择稀有度
    private func selectRarity(probabilities: [Double]) -> String {
        let random = Double.random(in: 0..<1)
        var cumulative: Double = 0

        let rarities = ["common", "rare", "epic"]
        for (index, prob) in probabilities.enumerated() {
            cumulative += prob
            if random < cumulative {
                return rarities[index]
            }
        }

        return "common"
    }

    // MARK: - 辅助方法

    /// 加载物品定义
    private func loadItemDefinitions() async {
        do {
            let items: [DBItemDefinition] = try await supabase
                .from("item_definitions")
                .select()
                .execute()
                .value

            itemDefinitionsCache = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            print("🔍 加载了 \(items.count) 个物品定义")
        } catch {
            print("❌ 加载物品定义失败: \(error)")
        }
    }

    /// 编码物品列表为 JSON
    private func encodeItemsToJSON(_ items: [(itemId: String, quantity: Int)]) -> String {
        let dictArray = items.map { ["item_id": $0.itemId, "quantity": $0.quantity] as [String: Any] }
        guard let data = try? JSONSerialization.data(withJSONObject: dictArray),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// 启动时长计时器
    private func startDurationTimer() {
        currentDuration = 0
        currentDistance = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                self.currentDuration += 1
                self.currentDistance = self.locationManager.explorationDistance
            }
        }
    }

    /// 停止时长计时器
    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
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
