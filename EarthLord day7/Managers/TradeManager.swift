//
//  TradeManager.swift
//  EarthLord day7
//
//  交易管理器
//  负责交易挂单的创建、接受、取消，以及数据加载和评分
//

import Foundation
import Combine
import Supabase

/// 交易管理器
@MainActor
class TradeManager: ObservableObject {

    // MARK: - 单例

    static let shared = TradeManager()

    // MARK: - 发布的状态

    /// 我的挂单列表
    @Published var myOffers: [DBTradeOffer] = []

    /// 市场挂单列表（其他人的活跃挂单）
    @Published var marketOffers: [DBTradeOffer] = []

    /// 我的交易历史
    @Published var myHistory: [DBTradeHistory] = []

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String?

    // MARK: - 初始化

    private init() {
        print("🔄 TradeManager 初始化")
    }

    // MARK: - 创建挂单

    /// 创建交易挂单
    /// - Parameters:
    ///   - offeringItems: 提供的物品列表
    ///   - requestingItems: 需求的物品列表（可选，nil 为开放式挂单）
    ///   - expiresHours: 过期时间（小时），默认 24
    ///   - message: 留言（可选）
    /// - Returns: 创建的挂单 ID
    func createOffer(
        offeringItems: [TradeItem],
        requestingItems: [TradeItem]? = nil,
        expiresHours: Int = 24,
        message: String? = nil
    ) async throws -> UUID {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // 验证
        guard !offeringItems.isEmpty else {
            let error = TradeError.offeringItemsRequired
            errorMessage = error.localizedDescription
            throw error
        }

        do {
            let params = CreateOfferParams(
                offeringItems: offeringItems,
                requestingItems: requestingItems?.isEmpty == false ? requestingItems : nil,
                expiresHours: expiresHours,
                message: message?.isEmpty == false ? message : nil
            )

            let response = try await executeCreateTradeOffer(params: params)

            if response.success, let offerId = response.offerId {
                print("🔄 创建挂单成功: \(offerId)")
                // 刷新我的挂单列表
                await loadMyOffers()
                // 刷新背包（因为物品已被锁定）
                await InventoryManager.shared.loadInventory()
                return offerId
            } else {
                let error = TradeError.from(
                    errorCode: response.error ?? "unknown",
                    itemId: response.itemId,
                    available: response.available
                )
                errorMessage = error.localizedDescription
                throw error
            }
        } catch let error as TradeError {
            throw error
        } catch {
            let tradeError = TradeError.databaseError(error.localizedDescription)
            errorMessage = tradeError.localizedDescription
            print("❌ 创建挂单失败: \(error)")
            throw tradeError
        }
    }

    // MARK: - 接受挂单

    /// 接受交易挂单
    /// - Parameters:
    ///   - offerId: 挂单 ID
    ///   - buyerItems: 买家提供的物品列表（如果挂单有要求）
    /// - Returns: 交易历史 ID
    func acceptOffer(
        offerId: UUID,
        buyerItems: [TradeItem]? = nil
    ) async throws -> UUID {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let params = AcceptOfferParams(
                offerId: offerId.uuidString,
                buyerItems: buyerItems?.isEmpty == false ? buyerItems : nil
            )

            let response = try await executeAcceptTradeOffer(params: params)

            if response.success, let historyId = response.historyId {
                print("🔄 接受挂单成功: \(historyId)")
                // 刷新市场列表
                await loadMarketOffers()
                // 刷新背包
                await InventoryManager.shared.loadInventory()
                // 刷新历史
                await loadHistory()
                return historyId
            } else {
                let error = TradeError.from(
                    errorCode: response.error ?? "unknown",
                    itemId: response.itemId
                )
                errorMessage = error.localizedDescription
                throw error
            }
        } catch let error as TradeError {
            throw error
        } catch {
            let tradeError = TradeError.databaseError(error.localizedDescription)
            errorMessage = tradeError.localizedDescription
            print("❌ 接受挂单失败: \(error)")
            throw tradeError
        }
    }

    // MARK: - 取消挂单

    /// 取消交易挂单
    /// - Parameter offerId: 挂单 ID
    func cancelOffer(offerId: UUID) async throws {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let params = CancelOfferParams(offerId: offerId.uuidString)

            let response = try await executeCancelTradeOffer(params: params)

            if response.success {
                print("🔄 取消挂单成功: \(offerId)")
                // 刷新我的挂单列表
                await loadMyOffers()
                // 刷新背包（物品已退回）
                await InventoryManager.shared.loadInventory()
            } else {
                let error = TradeError.from(errorCode: response.error ?? "unknown")
                errorMessage = error.localizedDescription
                throw error
            }
        } catch let error as TradeError {
            throw error
        } catch {
            let tradeError = TradeError.databaseError(error.localizedDescription)
            errorMessage = tradeError.localizedDescription
            print("❌ 取消挂单失败: \(error)")
            throw tradeError
        }
    }

    // MARK: - 数据加载

    /// 加载我的挂单列表
    func loadMyOffers() async {
        guard let userId = await getCurrentUserId() else {
            errorMessage = String(localized: "trade_error_not_authenticated")
            print("❌ 加载我的挂单失败：未登录")
            return
        }

        do {
            let offers: [DBTradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            myOffers = offers
            print("🔄 加载了 \(offers.count) 个我的挂单")
        } catch {
            errorMessage = String(localized: "trade_error_load_failed")
            print("❌ 加载我的挂单失败: \(error)")
        }
    }

    /// 加载市场挂单列表（其他人的活跃挂单）
    func loadMarketOffers() async {
        guard let userId = await getCurrentUserId() else {
            errorMessage = String(localized: "trade_error_not_authenticated")
            print("❌ 加载市场挂单失败：未登录")
            return
        }

        do {
            let offers: [DBTradeOffer] = try await supabase
                .from("trade_offers")
                .select()
                .eq("status", value: "active")
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .neq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            marketOffers = offers
            print("🔄 加载了 \(offers.count) 个市场挂单")
        } catch {
            errorMessage = String(localized: "trade_error_load_failed")
            print("❌ 加载市场挂单失败: \(error)")
        }
    }

    /// 加载我的交易历史
    func loadHistory() async {
        guard let userId = await getCurrentUserId() else {
            errorMessage = String(localized: "trade_error_not_authenticated")
            print("❌ 加载交易历史失败：未登录")
            return
        }

        do {
            let history: [DBTradeHistory] = try await supabase
                .from("trade_history")
                .select()
                .or("seller_id.eq.\(userId.uuidString),buyer_id.eq.\(userId.uuidString)")
                .order("completed_at", ascending: false)
                .execute()
                .value

            myHistory = history
            print("🔄 加载了 \(history.count) 条交易历史")
        } catch {
            errorMessage = String(localized: "trade_error_load_failed")
            print("❌ 加载交易历史失败: \(error)")
        }
    }

    /// 加载所有交易数据
    func loadAll() async {
        isLoading = true
        errorMessage = nil

        await loadMyOffers()
        await loadMarketOffers()
        await loadHistory()

        isLoading = false
    }

    // MARK: - 评分

    /// 对交易进行评分
    /// - Parameters:
    ///   - historyId: 交易历史 ID
    ///   - rating: 评分 (1-5)
    ///   - comment: 评语（可选）
    func rateTradeHistory(historyId: UUID, rating: Int, comment: String? = nil) async throws {
        guard rating >= 1 && rating <= 5 else {
            throw TradeError.invalidRating
        }

        do {
            let params = RateTradeParams(
                historyId: historyId.uuidString,
                rating: rating,
                comment: comment?.isEmpty == false ? comment : nil
            )

            let response = try await executeRateTradeRPC(params: params)

            if response.success {
                print("🔄 评分成功: \(historyId) -> \(rating)")
                // 刷新历史
                await loadHistory()
            } else {
                let error = TradeError.from(errorCode: response.error ?? "unknown")
                errorMessage = error.localizedDescription
                throw error
            }
        } catch let error as TradeError {
            throw error
        } catch {
            let tradeError = TradeError.databaseError(error.localizedDescription)
            errorMessage = tradeError.localizedDescription
            print("❌ 评分失败: \(error)")
            throw tradeError
        }
    }

    // MARK: - 便捷属性

    /// 活跃的我的挂单数量
    var activeMyOffersCount: Int {
        myOffers.filter { $0.statusEnum == .active && !$0.isExpired }.count
    }

    /// 待评价的交易数量
    func pendingRatingCount(userId: UUID) -> Int {
        myHistory.filter { history in
            if history.sellerId == userId {
                // 我是卖家，检查是否已给买家评分
                return history.buyerRating == nil
            } else if history.buyerId == userId {
                // 我是买家，检查是否已给卖家评分
                return history.sellerRating == nil
            }
            return false
        }.count
    }

    // MARK: - 便捷方法：从背包物品创建 TradeItem

    /// 从普通背包物品创建 TradeItem
    func createTradeItem(from item: DBInventoryItem, quantity: Int, definition: DBItemDefinition?) -> TradeItem {
        TradeItem(
            itemId: item.id,
            itemType: "normal",
            itemName: definition?.name ?? item.itemId,
            quantity: quantity,
            category: definition?.category,
            rarity: definition?.rarity,
            icon: definition?.icon
        )
    }

    /// 从 AI 背包物品创建 TradeItem
    func createTradeItem(from item: DBAIInventoryItem, quantity: Int) -> TradeItem {
        TradeItem(
            itemId: item.id,
            itemType: "ai",
            itemName: item.name,
            quantity: quantity,
            category: item.category,
            rarity: item.rarity,
            icon: item.icon
        )
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
