//
//  TradeOfferCard.swift
//  EarthLord day7
//
//  挂单卡片组件
//  显示状态、剩余时间、提供物品、请求物品、操作按钮
//

import SwiftUI

/// 挂单卡片
struct TradeOfferCard: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let offer: DBTradeOffer
    let isOwner: Bool
    var onCancel: (() -> Void)? = nil
    var onAccept: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：状态 + 发布者/剩余时间
            HStack {
                TradeStatusBadge(status: offer.statusEnum)

                // 发布者信息（非自己的挂单显示）
                if !isOwner {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 11))
                        Text(String(offer.ownerId.uuidString.prefix(8)))
                            .font(.system(size: 11, design: .monospaced))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)
                }

                Spacer()

                // 剩余时间（仅活跃状态）
                if offer.statusEnum == .active {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(offer.formattedRemainingTime)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(offer.remainingSeconds < 3600 ? ApocalypseTheme.warning : ApocalypseTheme.textSecondary)
                }
            }

            // 留言（如果有）
            if let message = offer.message, !message.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.info)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.info.opacity(0.1))
                )
            }

            // 中部：物品交换展示
            HStack(spacing: 8) {
                // 提供物品
                VStack(alignment: .leading, spacing: 6) {
                    Text(languageManager.localizedString("trade_offering"))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    itemsStack(items: offer.offeringItems)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 交换图标
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ApocalypseTheme.primary)

                // 请求物品
                VStack(alignment: .trailing, spacing: 6) {
                    Text(languageManager.localizedString("trade_requesting"))
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    if offer.isOpenOffer {
                        Text(languageManager.localizedString("trade_open_offer"))
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.success)
                            .italic()
                    } else {
                        itemsStack(items: offer.requestingItems ?? [], alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // 已完成挂单：显示接受者信息
            if offer.statusEnum == .completed && isOwner, let acceptorId = offer.completedByUserId {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)

                    Text(languageManager.localizedString("trade_accepted_by"))
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(String(acceptorId.uuidString.prefix(8)))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    Spacer()

                    if let completedAt = offer.completedAt {
                        Text(formatDate(completedAt))
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ApocalypseTheme.success.opacity(0.1))
                )
            }

            // 底部：操作按钮
            if offer.statusEnum == .active {
                HStack(spacing: 10) {
                    if isOwner {
                        // 取消按钮
                        Button {
                            onCancel?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                Text(languageManager.localizedString("trade_btn_cancel"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(ApocalypseTheme.danger)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(ApocalypseTheme.danger, lineWidth: 1)
                            )
                        }
                    } else {
                        // 接受按钮
                        Button {
                            onAccept?()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                Text(languageManager.localizedString("trade_btn_accept"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ApocalypseTheme.success)
                            )
                        }
                    }

                    // 详情按钮
                    Button {
                        onTap?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                            Text(languageManager.localizedString("trade_btn_detail"))
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    /// 物品堆叠展示
    @ViewBuilder
    private func itemsStack(items: [TradeItem], alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            ForEach(items.prefix(3)) { item in
                TradeItemMiniCard(item: item)
            }

            // 如果超过3个，显示更多
            if items.count > 3 {
                Text("+\(items.count - 3) \(languageManager.localizedString("trade_more_items"))")
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 预览

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            TradeOfferCard(
                offer: DBTradeOffer(
                    id: UUID(),
                    ownerId: UUID(),
                    offeringItems: [
                        TradeItem(itemId: UUID(), itemType: "normal", itemName: "急救包", quantity: 5, category: "medical", rarity: "rare", icon: "cross.case.fill"),
                        TradeItem(itemId: UUID(), itemType: "normal", itemName: "面包", quantity: 10, category: "food", rarity: "common", icon: "fork.knife")
                    ],
                    requestingItems: [
                        TradeItem(itemId: UUID(), itemType: "normal", itemName: "钢铁", quantity: 20, category: "material", rarity: "uncommon", icon: "cube.fill")
                    ],
                    status: "active",
                    expiresAt: Date().addingTimeInterval(3600 * 5),
                    createdAt: Date(),
                    updatedAt: nil,
                    completedAt: nil,
                    completedByUserId: nil,
                    message: "希望尽快交易，急需材料！"
                ),
                isOwner: true,
                onCancel: {},
                onTap: {}
            )

            TradeOfferCard(
                offer: DBTradeOffer(
                    id: UUID(),
                    ownerId: UUID(),
                    offeringItems: [
                        TradeItem(itemId: UUID(), itemType: "ai", itemName: "神秘药剂", quantity: 1, category: "medical", rarity: "epic", icon: "flask.fill")
                    ],
                    requestingItems: nil,
                    status: "active",
                    expiresAt: Date().addingTimeInterval(1800),
                    createdAt: Date(),
                    updatedAt: nil,
                    completedAt: nil,
                    completedByUserId: nil,
                    message: nil
                ),
                isOwner: false,
                onAccept: {},
                onTap: {}
            )
        }
        .padding()
    }
    .background(ApocalypseTheme.background)
    .environmentObject(LanguageManager.shared)
}
