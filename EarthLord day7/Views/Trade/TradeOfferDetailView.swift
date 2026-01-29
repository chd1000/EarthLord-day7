//
//  TradeOfferDetailView.swift
//  EarthLord day7
//
//  挂单详情页面
//  显示挂单的完整信息，包括发布者、物品详情、库存检查等
//

import SwiftUI

/// 挂单详情视图
struct TradeOfferDetailView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let offer: DBTradeOffer
    let currentUserId: UUID?
    let onAccept: (() -> Void)?

    @StateObject private var inventoryManager = InventoryManager.shared

    /// 是否是自己的挂单
    private var isOwner: Bool {
        offer.ownerId == currentUserId
    }

    /// 检查是否有足够的物品（用于接受非开放式挂单）
    private var hasEnoughItems: Bool {
        guard !offer.isOpenOffer, let requestingItems = offer.requestingItems else {
            return true
        }

        for item in requestingItems {
            if item.itemTypeEnum == .ai {
                // AI 物品：通过名称匹配（AI物品名称唯一）
                if let inventoryItem = inventoryManager.aiInventoryItems.first(where: { $0.name == item.itemName }) {
                    if inventoryItem.quantity < item.quantity {
                        return false
                    }
                } else {
                    return false
                }
            } else {
                // 普通物品：通过物品定义名称匹配
                // 遍历背包物品，找到名称匹配的物品
                var totalQuantity = 0
                for inventoryItem in inventoryManager.inventoryItems {
                    if let definition = inventoryManager.getDefinition(for: inventoryItem.itemId),
                       definition.name == item.itemName {
                        totalQuantity += inventoryItem.quantity
                    }
                }
                if totalQuantity < item.quantity {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 状态和时间信息
                    statusSection

                    // 留言（如果有）
                    if let message = offer.message, !message.isEmpty {
                        messageSection(message)
                    }

                    // 提供物品
                    offeringSection

                    // 请求物品
                    requestingSection

                    // 接受按钮（非自己的活跃挂单）
                    if !isOwner && offer.statusEnum == .active {
                        acceptSection
                    }
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(languageManager.localizedString("trade_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .task {
                // 确保库存数据已加载，以便正确检查 hasEnoughItems
                if inventoryManager.inventoryItems.isEmpty && inventoryManager.aiInventoryItems.isEmpty {
                    await inventoryManager.loadInventory()
                }
                if inventoryManager.itemDefinitions.isEmpty {
                    await inventoryManager.loadItemDefinitions()
                }
            }
        }
    }

    // MARK: - 状态区域

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack {
                TradeStatusBadge(status: offer.statusEnum)

                Spacer()

                // 剩余时间（活跃状态）
                if offer.statusEnum == .active {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text(offer.formattedRemainingTime)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(offer.remainingSeconds < 3600 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
                }
            }

            Divider()

            // 发布时间
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text(languageManager.localizedString("trade_created_at"))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Spacer()

                if let createdAt = offer.createdAt {
                    Text(formatDate(createdAt))
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 过期时间
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text(languageManager.localizedString("trade_expires_at"))
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Spacer()

                Text(formatDate(offer.expiresAt))
                    .font(.system(size: 13))
                    .foregroundColor(offer.isExpired ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 留言区域

    private func messageSection(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.info)

                Text(languageManager.localizedString("trade_section_message"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.info.opacity(0.1))
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 提供物品区域

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(languageManager.localizedString("trade_offering"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Text("\(offer.totalOfferingQuantity) \(languageManager.localizedString("trade_items_total"))")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            ForEach(offer.offeringItems) { item in
                TradeItemCard(item: item)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 请求物品区域

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.success)

                Text(languageManager.localizedString("trade_requesting"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                if !offer.isOpenOffer {
                    Text("\(offer.totalRequestingQuantity) \(languageManager.localizedString("trade_items_total"))")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }

            if offer.isOpenOffer {
                // 开放式交易
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.success)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(languageManager.localizedString("trade_open_offer"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.success)

                        Text(languageManager.localizedString("trade_open_offer_desc"))
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ApocalypseTheme.success.opacity(0.1))
                )
            } else if let requestingItems = offer.requestingItems {
                ForEach(requestingItems) { item in
                    TradeItemCard(item: item)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 接受区域

    private var acceptSection: some View {
        VStack(spacing: 12) {
            // 库存检查（非开放式挂单）
            if !offer.isOpenOffer {
                HStack(spacing: 8) {
                    Image(systemName: hasEnoughItems ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(hasEnoughItems ? ApocalypseTheme.success : ApocalypseTheme.warning)

                    Text(hasEnoughItems
                        ? languageManager.localizedString("trade_inventory_enough")
                        : languageManager.localizedString("trade_inventory_not_enough"))
                        .font(.system(size: 13))
                        .foregroundColor(hasEnoughItems ? ApocalypseTheme.success : ApocalypseTheme.warning)

                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill((hasEnoughItems ? ApocalypseTheme.success : ApocalypseTheme.warning).opacity(0.1))
                )
            }

            // 接受按钮
            Button {
                onAccept?()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                    Text(languageManager.localizedString("trade_btn_accept"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(hasEnoughItems ? ApocalypseTheme.success : ApocalypseTheme.textMuted)
                )
            }
            .disabled(!hasEnoughItems)
        }
    }

    // MARK: - 辅助方法

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview {
    TradeOfferDetailView(
        offer: DBTradeOffer(
            id: UUID(),
            ownerId: UUID(),
            offeringItems: [
                TradeItem(itemId: UUID(), itemType: "normal", itemName: "急救包", quantity: 5, category: "medical", rarity: "rare", icon: "cross.case.fill"),
                TradeItem(itemId: UUID(), itemType: "ai", itemName: "神秘药剂", quantity: 1, category: "medical", rarity: "epic", icon: "flask.fill")
            ],
            requestingItems: [
                TradeItem(itemId: UUID(), itemType: "normal", itemName: "钢铁", quantity: 20, category: "material", rarity: "uncommon", icon: "cube.fill")
            ],
            status: "active",
            expiresAt: Date().addingTimeInterval(3600 * 12),
            createdAt: Date().addingTimeInterval(-3600 * 2),
            updatedAt: nil,
            completedAt: nil,
            completedByUserId: nil,
            message: "希望能尽快完成交易"
        ),
        currentUserId: UUID(),
        onAccept: {}
    )
    .environmentObject(LanguageManager.shared)
}
