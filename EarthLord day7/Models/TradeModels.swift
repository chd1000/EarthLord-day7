//
//  TradeModels.swift
//  EarthLord day7
//
//  交易系统数据模型
//  包含交易状态、物品类型、挂单模型、历史记录、错误类型
//

import Foundation

// MARK: - 交易状态枚举

/// 交易挂单状态
enum TradeStatus: String, Codable, CaseIterable {
    case active = "active"           // 活跃中
    case completed = "completed"     // 已完成
    case cancelled = "cancelled"     // 已取消
    case expired = "expired"         // 已过期

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .active: return String(localized: "trade_status_active")
        case .completed: return String(localized: "trade_status_completed")
        case .cancelled: return String(localized: "trade_status_cancelled")
        case .expired: return String(localized: "trade_status_expired")
        }
    }

    /// 状态图标
    var icon: String {
        switch self {
        case .active: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .expired: return "clock.badge.exclamationmark.fill"
        }
    }
}

// MARK: - 交易物品类型枚举

/// 交易物品类型
enum TradeItemType: String, Codable {
    case normal = "normal"   // 普通物品
    case ai = "ai"           // AI 生成物品

    /// 本地化显示名称
    var displayName: String {
        switch self {
        case .normal: return String(localized: "trade_item_type_normal")
        case .ai: return String(localized: "trade_item_type_ai")
        }
    }
}

// MARK: - 交易物品模型（JSON 格式）

/// 交易物品（用于 JSON 序列化）
struct TradeItem: Codable, Identifiable, Equatable, Sendable {
    let itemId: UUID
    let itemType: String        // "normal" | "ai"
    let itemName: String
    let quantity: Int
    let category: String?
    let rarity: String?
    let icon: String?

    var id: UUID { itemId }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case itemType = "item_type"
        case itemName = "item_name"
        case quantity
        case category
        case rarity
        case icon
    }

    /// 获取物品类型枚举
    var itemTypeEnum: TradeItemType {
        TradeItemType(rawValue: itemType) ?? .normal
    }

    /// 稀有度显示名称
    var rarityDisplayName: String {
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "少见"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return rarity ?? ""
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
        case "water": return "水类"
        case "weapon": return "武器"
        default: return category ?? ""
        }
    }
}

// MARK: - 交易挂单模型（映射 trade_offers 表）

/// 交易挂单
struct DBTradeOffer: Codable, Identifiable {
    let id: UUID
    let ownerId: UUID
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]?
    let status: String
    let expiresAt: Date
    let createdAt: Date?
    let updatedAt: Date?
    let completedAt: Date?
    let completedByUserId: UUID?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case completedAt = "completed_at"
        case completedByUserId = "completed_by_user_id"
        case message
    }

    /// 获取状态枚举
    var statusEnum: TradeStatus {
        TradeStatus(rawValue: status) ?? .active
    }

    /// 是否已过期
    var isExpired: Bool {
        Date() > expiresAt
    }

    /// 剩余时间（秒）
    var remainingSeconds: Int {
        max(0, Int(expiresAt.timeIntervalSince(Date())))
    }

    /// 格式化剩余时间
    var formattedRemainingTime: String {
        let seconds = remainingSeconds
        if seconds <= 0 {
            return String(localized: "trade_expired")
        }

        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    /// 是否是开放式挂单（不要求特定物品）
    var isOpenOffer: Bool {
        requestingItems == nil || requestingItems?.isEmpty == true
    }

    /// 提供物品的总数量
    var totalOfferingQuantity: Int {
        offeringItems.reduce(0) { $0 + $1.quantity }
    }

    /// 需求物品的总数量
    var totalRequestingQuantity: Int {
        requestingItems?.reduce(0) { $0 + $1.quantity } ?? 0
    }

    /// 格式化完成时间
    var formattedCompletedAt: String {
        guard let date = completedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// 插入交易挂单（用于客户端参考，实际通过 RPC 创建）
struct DBTradeOfferInsert: Codable {
    let ownerId: UUID
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]?
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case offeringItems = "offering_items"
        case requestingItems = "requesting_items"
        case expiresAt = "expires_at"
    }
}

// MARK: - 交易历史中的物品交换记录

/// 交换物品记录（JSON 格式）
struct ItemsExchanged: Codable {
    let sellerItems: [TradeItem]
    let buyerItems: [TradeItem]

    enum CodingKeys: String, CodingKey {
        case sellerItems = "seller_items"
        case buyerItems = "buyer_items"
    }
}

// MARK: - 交易历史模型（映射 trade_history 表）

/// 交易历史记录
struct DBTradeHistory: Codable, Identifiable {
    let id: UUID
    let offerId: UUID
    let sellerId: UUID
    let buyerId: UUID
    let itemsExchanged: ItemsExchanged
    let completedAt: Date?
    var sellerRating: Int?
    var buyerRating: Int?
    var sellerComment: String?
    var buyerComment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case itemsExchanged = "items_exchanged"
        case completedAt = "completed_at"
        case sellerRating = "seller_rating"
        case buyerRating = "buyer_rating"
        case sellerComment = "seller_comment"
        case buyerComment = "buyer_comment"
    }

    /// 格式化完成时间
    var formattedCompletedAt: String {
        guard let date = completedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// 卖家交出的物品
    var sellerItems: [TradeItem] {
        itemsExchanged.sellerItems
    }

    /// 买家交出的物品
    var buyerItems: [TradeItem] {
        itemsExchanged.buyerItems
    }
}

/// 插入交易历史（用于客户端参考，实际通过 RPC 创建）
struct DBTradeHistoryInsert: Codable {
    let offerId: UUID
    let sellerId: UUID
    let buyerId: UUID
    let itemsExchanged: ItemsExchanged

    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case sellerId = "seller_id"
        case buyerId = "buyer_id"
        case itemsExchanged = "items_exchanged"
    }
}

// MARK: - 交易错误枚举

/// 交易系统错误
enum TradeError: Error, LocalizedError {
    case notAuthenticated              // 未登录
    case offeringItemsRequired         // 需要提供物品
    case itemNotFound(UUID?)           // 物品未找到
    case insufficientQuantity(UUID?, Int)  // 数量不足
    case invalidItemType               // 无效物品类型
    case offerNotFound                 // 挂单未找到
    case offerNotActive                // 挂单非活跃状态
    case offerExpired                  // 挂单已过期
    case cannotAcceptOwnOffer          // 不能接受自己的挂单
    case notOwner                      // 不是挂单所有者
    case buyerItemsRequired            // 需要提供交换物品
    case buyerItemNotFound(UUID?)      // 买家物品未找到
    case buyerInsufficientQuantity(UUID?)  // 买家物品数量不足
    case alreadyRated                  // 已评价
    case invalidRating                 // 无效评分
    case notParticipant                // 非交易参与者
    case historyNotFound               // 历史记录未找到
    case databaseError(String)         // 数据库错误
    case unknownError(String)          // 未知错误

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return String(localized: "trade_error_not_authenticated")
        case .offeringItemsRequired:
            return String(localized: "trade_error_offering_required")
        case .itemNotFound(let itemId):
            let base = String(localized: "trade_error_item_not_found")
            if let id = itemId { return "\(base) (\(id.uuidString.prefix(8))...)" }
            return base
        case .insufficientQuantity(let itemId, let available):
            let base = String(localized: "trade_error_insufficient_quantity")
            if let id = itemId { return "\(base) (\(id.uuidString.prefix(8))..., \(available))" }
            return "\(base) (\(available))"
        case .invalidItemType:
            return String(localized: "trade_error_invalid_item_type")
        case .offerNotFound:
            return String(localized: "trade_error_offer_not_found")
        case .offerNotActive:
            return String(localized: "trade_error_offer_not_active")
        case .offerExpired:
            return String(localized: "trade_error_offer_expired")
        case .cannotAcceptOwnOffer:
            return String(localized: "trade_error_cannot_accept_own")
        case .notOwner:
            return String(localized: "trade_error_not_owner")
        case .buyerItemsRequired:
            return String(localized: "trade_error_buyer_items_required")
        case .buyerItemNotFound(let itemId):
            let base = String(localized: "trade_error_buyer_item_not_found")
            if let id = itemId { return "\(base) (\(id.uuidString.prefix(8))...)" }
            return base
        case .buyerInsufficientQuantity(let itemId):
            let base = String(localized: "trade_error_buyer_insufficient")
            if let id = itemId { return "\(base) (\(id.uuidString.prefix(8))...)" }
            return base
        case .alreadyRated:
            return String(localized: "trade_error_already_rated")
        case .invalidRating:
            return String(localized: "trade_error_invalid_rating")
        case .notParticipant:
            return String(localized: "trade_error_not_participant")
        case .historyNotFound:
            return String(localized: "trade_error_history_not_found")
        case .databaseError(let message):
            return String(localized: "trade_error_database") + ": \(message)"
        case .unknownError(let message):
            return message
        }
    }

    /// 从 RPC 响应错误码创建
    static func from(errorCode: String, itemId: UUID? = nil, available: Int? = nil) -> TradeError {
        switch errorCode {
        case "not_authenticated": return .notAuthenticated
        case "offering_items_required": return .offeringItemsRequired
        case "item_not_found": return .itemNotFound(itemId)
        case "insufficient_quantity": return .insufficientQuantity(itemId, available ?? 0)
        case "invalid_item_type": return .invalidItemType
        case "offer_not_found": return .offerNotFound
        case "offer_not_active": return .offerNotActive
        case "offer_expired": return .offerExpired
        case "cannot_accept_own_offer": return .cannotAcceptOwnOffer
        case "not_owner": return .notOwner
        case "buyer_items_required": return .buyerItemsRequired
        case "buyer_item_not_found": return .buyerItemNotFound(itemId)
        case "buyer_insufficient_quantity": return .buyerInsufficientQuantity(itemId)
        case "already_rated": return .alreadyRated
        case "invalid_rating": return .invalidRating
        case "not_participant": return .notParticipant
        case "history_not_found": return .historyNotFound
        default: return .unknownError(errorCode)
        }
    }
}

// MARK: - RPC 响应模型

/// 创建挂单响应
struct CreateOfferResponse: Sendable {
    let success: Bool
    let offerId: UUID?
    let expiresAt: Date?
    let error: String?
    let itemId: UUID?
    let available: Int?

    private enum CodingKeys: String, CodingKey {
        case success
        case offerId = "offer_id"
        case expiresAt = "expires_at"
        case error
        case itemId = "item_id"
        case available
    }
}

extension CreateOfferResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        offerId = try container.decodeIfPresent(UUID.self, forKey: .offerId)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        itemId = try container.decodeIfPresent(UUID.self, forKey: .itemId)
        available = try container.decodeIfPresent(Int.self, forKey: .available)
    }
}

/// 接受挂单响应
struct AcceptOfferResponse: Sendable {
    let success: Bool
    let historyId: UUID?
    let error: String?
    let itemId: UUID?

    private enum CodingKeys: String, CodingKey {
        case success
        case historyId = "history_id"
        case error
        case itemId = "item_id"
    }
}

extension AcceptOfferResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        historyId = try container.decodeIfPresent(UUID.self, forKey: .historyId)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        itemId = try container.decodeIfPresent(UUID.self, forKey: .itemId)
    }
}

/// 取消挂单响应
struct CancelOfferResponse: Sendable {
    let success: Bool
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success, error
    }
}

extension CancelOfferResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

/// 评分响应
struct RateTradeResponse: Sendable {
    let success: Bool
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case success, error
    }
}

extension RateTradeResponse: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}
