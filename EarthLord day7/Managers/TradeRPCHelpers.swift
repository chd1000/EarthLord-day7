//
//  TradeRPCHelpers.swift
//  EarthLord day7
//
//  交易系统 RPC 辅助类型和执行函数
//

import Foundation
@preconcurrency import Supabase

// MARK: - RPC 参数结构体

/// 创建挂单参数
struct CreateOfferParams: Sendable {
    let offeringItems: [TradeItem]
    let requestingItems: [TradeItem]?
    let expiresHours: Int
    let message: String?
}

/// 接受挂单参数
struct AcceptOfferParams: Sendable {
    let offerId: String
    let buyerItems: [TradeItem]?
}

/// 取消挂单参数
struct CancelOfferParams: Sendable {
    let offerId: String
}

/// 评分参数
struct RateTradeParams: Sendable {
    let historyId: String
    let rating: Int
    let comment: String?
}

// MARK: - Encodable RPC 参数

struct RPCCreateParams: Sendable {
    let p_offering_items: String
    let p_requesting_items: String?
    let p_expires_hours: Int
    let p_message: String?
}

extension RPCCreateParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_offering_items, forKey: .p_offering_items)
        try container.encodeIfPresent(p_requesting_items, forKey: .p_requesting_items)
        try container.encode(p_expires_hours, forKey: .p_expires_hours)
        try container.encodeIfPresent(p_message, forKey: .p_message)
    }

    private enum CodingKeys: String, CodingKey {
        case p_offering_items, p_requesting_items, p_expires_hours, p_message
    }
}

struct RPCAcceptParams: Sendable {
    let p_offer_id: String
    let p_buyer_items: String?
}

extension RPCAcceptParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_offer_id, forKey: .p_offer_id)
        try container.encodeIfPresent(p_buyer_items, forKey: .p_buyer_items)
    }

    private enum CodingKeys: String, CodingKey {
        case p_offer_id, p_buyer_items
    }
}

struct RPCCancelParams: Sendable {
    let p_offer_id: String
}

extension RPCCancelParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_offer_id, forKey: .p_offer_id)
    }

    private enum CodingKeys: String, CodingKey {
        case p_offer_id
    }
}

struct RPCRateParams: Sendable {
    let p_history_id: String
    let p_rating: Int
    let p_comment: String?
}

extension RPCRateParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_history_id, forKey: .p_history_id)
        try container.encode(p_rating, forKey: .p_rating)
        // 始终包含 p_comment 参数，即使为空字符串，避免 PostgreSQL 函数重载歧义
        try container.encode(p_comment ?? "", forKey: .p_comment)
    }

    private enum CodingKeys: String, CodingKey {
        case p_history_id, p_rating, p_comment
    }
}

// MARK: - TradeItem 转换

private nonisolated func itemsToJSON(_ items: [TradeItem]) -> String {
    let array = items.map { item -> [String: Any] in
        var dict: [String: Any] = [
            "item_id": item.itemId.uuidString,
            "item_type": item.itemType,
            "item_name": item.itemName,
            "quantity": item.quantity
        ]
        if let cat = item.category { dict["category"] = cat }
        if let rar = item.rarity { dict["rarity"] = rar }
        if let ico = item.icon { dict["icon"] = ico }
        return dict
    }
    guard let data = try? JSONSerialization.data(withJSONObject: array),
          let str = String(data: data, encoding: .utf8) else {
        return "[]"
    }
    return str
}

// MARK: - 日期格式化器（支持 PostgreSQL 带小数秒的 ISO8601 格式）

/// 创建支持 PostgreSQL 时间戳格式的 JSONDecoder
private nonisolated func createTradeDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        // 尝试带小数秒的 ISO8601 格式
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: dateString) {
            return date
        }

        // 尝试不带小数秒的 ISO8601 格式
        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]
        if let date = basicFormatter.date(from: dateString) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析日期: \(dateString)")
    }
    return decoder
}

// MARK: - RPC 执行函数

/// 执行创建挂单 RPC
nonisolated func executeCreateTradeOffer(params: CreateOfferParams) async throws -> CreateOfferResponse {
    let rpcParams = RPCCreateParams(
        p_offering_items: itemsToJSON(params.offeringItems),
        p_requesting_items: params.requestingItems.map { itemsToJSON($0) },
        p_expires_hours: params.expiresHours,
        p_message: params.message
    )

    let response = try await supabase
        .rpc("create_trade_offer_v2", params: rpcParams)
        .execute()

    return try createTradeDecoder().decode(CreateOfferResponse.self, from: response.data)
}

/// 执行接受挂单 RPC
nonisolated func executeAcceptTradeOffer(params: AcceptOfferParams) async throws -> AcceptOfferResponse {
    let rpcParams = RPCAcceptParams(
        p_offer_id: params.offerId,
        p_buyer_items: params.buyerItems.map { itemsToJSON($0) }
    )

    let response = try await supabase
        .rpc("accept_trade_offer_v2", params: rpcParams)
        .execute()

    let decoder = JSONDecoder()
    return try decoder.decode(AcceptOfferResponse.self, from: response.data)
}

/// 执行取消挂单 RPC
nonisolated func executeCancelTradeOffer(params: CancelOfferParams) async throws -> CancelOfferResponse {
    let rpcParams = RPCCancelParams(p_offer_id: params.offerId)

    let response = try await supabase
        .rpc("cancel_trade_offer", params: rpcParams)
        .execute()

    let decoder = JSONDecoder()
    return try decoder.decode(CancelOfferResponse.self, from: response.data)
}

/// 执行评分 RPC
nonisolated func executeRateTradeRPC(params: RateTradeParams) async throws -> RateTradeResponse {
    let rpcParams = RPCRateParams(
        p_history_id: params.historyId,
        p_rating: params.rating,
        p_comment: params.comment
    )

    let response = try await supabase
        .rpc("rate_trade", params: rpcParams)
        .execute()

    let decoder = JSONDecoder()
    return try decoder.decode(RateTradeResponse.self, from: response.data)
}
