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
import UIKit

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

    // MARK: - POI搜刮相关状态

    /// 附近的POI列表
    @Published var nearbyPOIs: [POI] = []

    /// 当前接近的POI（触发弹窗）
    @Published var currentProximityPOI: POI?

    /// 是否显示接近弹窗
    @Published var showProximityPopup: Bool = false

    /// 搜刮结果
    @Published var scavengeResult: ScavengeResult?

    /// 是否显示搜刮结果
    @Published var showScavengeResult: Bool = false

    /// 是否正在搜刮
    @Published var isScavenging: Bool = false

    /// POI更新版本（用于触发地图刷新）
    @Published var poiUpdateVersion: Int = 0

    // MARK: - 私有属性

    private var locationManager = LocationManager.shared
    private var inventoryManager = InventoryManager.shared
    private var playerLocationManager = PlayerLocationManager.shared
    private var durationTimer: Timer?
    private var itemDefinitionsCache: [String: DBItemDefinition] = [:]

    /// 超速通知监听器
    private var overSpeedObserver: NSObjectProtocol?

    /// POI接近检测定时器
    private var proximityCheckTimer: Timer?

    /// 接近检测间隔（秒）
    private let proximityCheckInterval: TimeInterval = 3.0

    /// 搜刮触发距离（米）
    private let scavengeRadius: Double = 50.0

    /// POI搜索管理器
    private var poiSearchManager = POISearchManager.shared

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

            // 7. 搜索附近POI
            await searchNearbyPOIs()

            // 8. 启动POI接近检测
            startProximityMonitoring()

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

        // 停止POI接近检测
        stopProximityMonitoring()
        clearPOIs()

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

        // 停止POI接近检测
        stopProximityMonitoring()
        clearPOIs()

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

    // MARK: - POI搜刮功能

    /// 搜索附近POI
    /// 根据附近玩家密度动态调整POI显示数量
    func searchNearbyPOIs() async {
        guard let currentLocation = locationManager.userLocation else {
            print("⚠️ [POI] 无法获取当前位置")
            TerritoryLogger.shared.log("无法获取位置", type: .error)
            return
        }

        print("🔍 [POI] 开始搜索附近POI，位置: (\(currentLocation.latitude), \(currentLocation.longitude))")
        TerritoryLogger.shared.log("正在搜索附近地点...", type: .info)

        // 1. 先上报自己位置
        await playerLocationManager.reportLocation()

        // 2. 查询附近玩家数量
        let nearbyCount = await playerLocationManager.queryNearbyPlayers()
        let densityLevel = PlayerDensityLevel.from(playerCount: nearbyCount)

        // 3. 根据密度决定POI数量
        let maxPOI = densityLevel.maxPOICount

        print("🔍 [POI] 附近\(nearbyCount)人，密度等级: \(densityLevel.displayName)，显示\(maxPOI)个POI")

        // 显示玩家密度信息
        TerritoryLogger.shared.log("附近玩家: \(nearbyCount) 人, 密度: \(densityLevel.displayName)", type: .info)

        // 4. 搜索POI
        let pois = await poiSearchManager.searchNearbyPOIs(center: currentLocation, maxCount: maxPOI)

        nearbyPOIs = pois
        poiUpdateVersion += 1

        if pois.isEmpty {
            print("⚠️ [POI] 附近未找到可探索地点")
            TerritoryLogger.shared.log("附近未发现可探索地点", type: .warning)
        } else {
            print("🔍 [POI] 共加载 \(pois.count) 个POI")
            TerritoryLogger.shared.log("发现 \(pois.count) 个可探索地点", type: .success)
        }
    }

    /// 启动POI接近检测
    func startProximityMonitoring() {
        print("🔍 [POI] 启动接近检测")

        proximityCheckTimer = Timer.scheduledTimer(withTimeInterval: proximityCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPOIProximity()
            }
        }
    }

    /// 停止POI接近检测
    func stopProximityMonitoring() {
        proximityCheckTimer?.invalidate()
        proximityCheckTimer = nil
        print("🔍 [POI] 停止接近检测")
    }

    /// 清除POI数据
    func clearPOIs() {
        nearbyPOIs.removeAll()
        currentProximityPOI = nil
        showProximityPopup = false
        poiSearchManager.clearSearchResults()
        poiUpdateVersion += 1
        print("🔍 [POI] 已清除POI数据")
    }

    /// 检查是否接近POI
    private func checkPOIProximity() {
        guard let userLocation = locationManager.userLocation else { return }

        // 用户位置是WGS-84，POI坐标是GCJ-02，需要转换用户位置到GCJ-02再计算距离
        let userGCJ02 = CoordinateConverter.wgs84ToGcj02([userLocation]).first ?? userLocation
        let userCLLocation = CLLocation(latitude: userGCJ02.latitude, longitude: userGCJ02.longitude)

        // 更新所有POI的距离
        for i in 0..<nearbyPOIs.count {
            let poiLocation = CLLocation(
                latitude: nearbyPOIs[i].coordinate.latitude,
                longitude: nearbyPOIs[i].coordinate.longitude
            )
            nearbyPOIs[i].distanceFromUser = userCLLocation.distance(from: poiLocation)
        }

        // 查找最近的可搜刮POI
        let scavengablePOIs = nearbyPOIs.filter { poi in
            guard let distance = poi.distanceFromUser else { return false }
            return distance <= scavengeRadius && poi.canScavenge
        }

        // 如果有可搜刮的POI，选择最近的一个
        if let closestPOI = scavengablePOIs.min(by: { ($0.distanceFromUser ?? .infinity) < ($1.distanceFromUser ?? .infinity) }) {
            // 只有当POI变化时才更新
            if currentProximityPOI?.id != closestPOI.id {
                currentProximityPOI = closestPOI
                showProximityPopup = true

                // 震动提示
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                print("🔍 [POI] 进入搜刮范围: \(closestPOI.name)")
                TerritoryLogger.shared.log("发现可搜刮地点: \(closestPOI.name)", type: .warning)
            }
        } else {
            // 离开搜刮范围
            if currentProximityPOI != nil {
                print("🔍 [POI] 离开搜刮范围")
                currentProximityPOI = nil
                showProximityPopup = false
            }
        }
    }

    /// 关闭接近弹窗
    func dismissProximityPopup() {
        showProximityPopup = false
    }

    /// 执行搜刮（使用 AI 生成物品）
    func performScavenge(poi: POI) async {
        guard poi.canScavenge else {
            print("⚠️ [POI] 该地点无法搜刮")
            return
        }

        isScavenging = true
        showProximityPopup = false

        print("🔍 [POI] 开始搜刮: \(poi.name)")
        TerritoryLogger.shared.log("正在搜刮: \(poi.name)", type: .info)

        // 根据危险等级确定物品数量
        let itemCount = min(poi.dangerLevel + 1, 5)

        // 1. 调用 AI 生成物品
        let aiItems = await AIItemGenerator.shared.generateItems(for: poi, count: itemCount)

        // 2. 如果 AI 失败，使用降级方案
        let items = aiItems ?? AIItemGenerator.shared.generateFallbackItems(for: poi, count: itemCount)
        let isAIGenerated = aiItems != nil

        // 3. 保存到数据库
        _ = await AIItemGenerator.shared.saveToInventory(items: items, poi: poi)

        // 4. 转换为 ScavengedItem 用于显示
        let rewards = items.map { item in
            ScavengeResult.ScavengedItem(
                itemId: UUID().uuidString,  // AI 物品使用临时 ID
                name: item.name,
                quantity: 1,
                rarity: item.rarity,
                icon: item.icon,
                category: item.category,
                story: item.story,
                isAIGenerated: isAIGenerated
            )
        }

        // 5. 创建搜刮结果
        let result = ScavengeResult(
            poiId: poi.id,
            poiName: poi.name,
            poiType: poi.type,
            items: rewards,
            isAIGenerated: isAIGenerated
        )

        // 6. 通知 InventoryManager 刷新 AI 物品
        await inventoryManager.loadAIInventory()

        // 7. 标记POI为已搜刮
        if let index = nearbyPOIs.firstIndex(where: { $0.id == poi.id }) {
            nearbyPOIs[index].status = .looted
            nearbyPOIs[index].hasLoot = false
            nearbyPOIs[index].lastLootedAt = Date()
        }

        scavengeResult = result
        isScavenging = false
        showScavengeResult = true
        currentProximityPOI = nil
        poiUpdateVersion += 1

        print("🔍 [POI] 搜刮完成，获得 \(rewards.count) 种\(isAIGenerated ? "AI生成" : "预设")物品")
        TerritoryLogger.shared.log("搜刮成功: 获得 \(rewards.count) 种物品", type: .success)
    }

    /// 生成搜刮奖励
    private func generateScavengeRewards(poi: POI) -> [ScavengeResult.ScavengedItem] {
        // 根据POI类型和危险等级确定奖励
        let itemCount = Int.random(in: 1...3)
        var rewards: [ScavengeResult.ScavengedItem] = []

        // 根据POI类型调整物品类别概率
        let categoryProbabilities = getCategoryProbabilities(for: poi.type)

        for _ in 0..<itemCount {
            // 选择物品类别
            let category = selectCategory(probabilities: categoryProbabilities)

            // 从该类别中随机选择物品
            let itemsOfCategory = itemDefinitionsCache.values.filter { $0.category == category }
            guard let selectedItem = itemsOfCategory.randomElement() else { continue }

            let quantity = Int.random(in: 1...2)

            rewards.append(ScavengeResult.ScavengedItem(
                itemId: selectedItem.id,
                name: selectedItem.name,
                quantity: quantity,
                rarity: selectedItem.rarity,
                icon: selectedItem.icon,
                category: selectedItem.category
            ))
        }

        return rewards
    }

    /// 根据POI类型获取物品类别概率
    private func getCategoryProbabilities(for poiType: POIType) -> [String: Double] {
        switch poiType {
        case .hospital, .pharmacy:
            return ["medical": 0.6, "food": 0.2, "tool": 0.15, "material": 0.05]
        case .supermarket:
            return ["food": 0.5, "medical": 0.2, "tool": 0.2, "material": 0.1]
        case .gasStation:
            return ["tool": 0.4, "material": 0.3, "food": 0.2, "medical": 0.1]
        case .police, .military:
            return ["tool": 0.5, "material": 0.3, "medical": 0.15, "food": 0.05]
        case .warehouse, .factory:
            return ["material": 0.5, "tool": 0.3, "food": 0.1, "medical": 0.1]
        case .house:
            return ["food": 0.4, "medical": 0.2, "tool": 0.2, "material": 0.2]
        }
    }

    /// 根据概率选择物品类别
    private func selectCategory(probabilities: [String: Double]) -> String {
        let random = Double.random(in: 0..<1)
        var cumulative: Double = 0

        for (category, prob) in probabilities {
            cumulative += prob
            if random < cumulative {
                return category
            }
        }

        return "food" // 默认
    }

    /// 关闭搜刮结果弹窗
    func dismissScavengeResult() {
        showScavengeResult = false
        scavengeResult = nil
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

        // 停止POI接近检测
        stopProximityMonitoring()
        clearPOIs()

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
