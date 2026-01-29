//
//  TradeHistoryCard.swift
//  EarthLord day7
//
//  交易历史卡片组件
//  显示交易对方、完成时间、给出/获得物品、评分状态
//

import SwiftUI

/// 交易历史卡片
struct TradeHistoryCard: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let history: DBTradeHistory
    let currentUserId: UUID
    var onRate: (() -> Void)? = nil

    /// 当前用户是否是卖家
    private var isSeller: Bool {
        history.sellerId == currentUserId
    }

    /// 我给出的物品
    private var itemsGiven: [TradeItem] {
        isSeller ? history.sellerItems : history.buyerItems
    }

    /// 我获得的物品
    private var itemsReceived: [TradeItem] {
        isSeller ? history.buyerItems : history.sellerItems
    }

    /// 是否需要评价
    private var needsRating: Bool {
        if isSeller {
            return history.buyerRating == nil
        } else {
            return history.sellerRating == nil
        }
    }

    /// 已给出的评分
    private var givenRating: Int? {
        if isSeller {
            return history.buyerRating
        } else {
            return history.sellerRating
        }
    }

    /// 交易对方ID
    private var counterpartyId: UUID {
        isSeller ? history.buyerId : history.sellerId
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：交易对方 + 完成时间 + 评价状态
            HStack {
                // 交易对方
                HStack(spacing: 4) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.primary)

                    Text(languageManager.localizedString("trade_with"))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(String(counterpartyId.uuidString.prefix(8)))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                // 完成时间
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(ApocalypseTheme.success)

                    Text(history.formattedCompletedAt)
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }

            // 评价状态行
            HStack {
                Spacer()

                // 评价状态
                if let rating = givenRating {
                    // 已评价
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                    }
                } else {
                    // 待评价
                    Text(languageManager.localizedString("trade_pending_rating"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ApocalypseTheme.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.warning.opacity(0.15))
                        )
                }
            }

            // 中部：物品交换展示
            HStack(spacing: 8) {
                // 给出的物品
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.danger)
                        Text(languageManager.localizedString("trade_given"))
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }

                    itemsStack(items: itemsGiven)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 交换图标
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)

                // 获得的物品
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(languageManager.localizedString("trade_received"))
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.success)
                    }

                    itemsStack(items: itemsReceived, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // 底部：评价按钮（如果需要）
            if needsRating {
                Button {
                    onRate?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "star")
                            .font(.system(size: 12))
                        Text(languageManager.localizedString("trade_btn_rate"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(ApocalypseTheme.primary)
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    /// 物品堆叠展示
    @ViewBuilder
    private func itemsStack(items: [TradeItem], alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            ForEach(items.prefix(2)) { item in
                TradeItemMiniCard(item: item)
            }

            if items.count > 2 {
                Text("+\(items.count - 2) \(languageManager.localizedString("trade_more_items"))")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }
}

// MARK: - 预览

#Preview {
    let userId = UUID()

    return ScrollView {
        VStack(spacing: 16) {
            TradeHistoryCard(
                history: DBTradeHistory(
                    id: UUID(),
                    offerId: UUID(),
                    sellerId: userId,
                    buyerId: UUID(),
                    itemsExchanged: ItemsExchanged(
                        sellerItems: [
                            TradeItem(itemId: UUID(), itemType: "normal", itemName: "急救包", quantity: 5, category: "medical", rarity: "rare", icon: "cross.case.fill")
                        ],
                        buyerItems: [
                            TradeItem(itemId: UUID(), itemType: "normal", itemName: "钢铁", quantity: 20, category: "material", rarity: "uncommon", icon: "cube.fill")
                        ]
                    ),
                    completedAt: Date().addingTimeInterval(-3600 * 24),
                    sellerRating: nil,
                    buyerRating: nil
                ),
                currentUserId: userId,
                onRate: {}
            )

            TradeHistoryCard(
                history: DBTradeHistory(
                    id: UUID(),
                    offerId: UUID(),
                    sellerId: UUID(),
                    buyerId: userId,
                    itemsExchanged: ItemsExchanged(
                        sellerItems: [
                            TradeItem(itemId: UUID(), itemType: "ai", itemName: "神秘药剂", quantity: 1, category: "medical", rarity: "epic", icon: "flask.fill")
                        ],
                        buyerItems: [
                            TradeItem(itemId: UUID(), itemType: "normal", itemName: "金币", quantity: 100, category: "material", rarity: "rare", icon: "bitcoinsign.circle.fill")
                        ]
                    ),
                    completedAt: Date().addingTimeInterval(-3600 * 48),
                    sellerRating: 5,
                    buyerRating: 4
                ),
                currentUserId: userId
            )
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
    .environmentObject(LanguageManager.shared)
}
