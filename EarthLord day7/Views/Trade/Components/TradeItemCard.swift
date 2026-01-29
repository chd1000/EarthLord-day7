//
//  TradeItemCard.swift
//  EarthLord day7
//
//  交易物品卡片组件
//

import SwiftUI

/// 交易物品卡片
struct TradeItemCard: View {
    let item: TradeItem
    var showDeleteButton: Bool = false
    var onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 圆形图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon ?? "cube.fill")
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.itemName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // 数量
                    Text("x\(item.quantity)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.primary)

                    // 稀有度标签
                    if let rarity = item.rarity {
                        RarityBadge(rarity: rarity)
                    }

                    // AI物品标记
                    if item.itemTypeEnum == .ai {
                        AIBadge()
                    }
                }
            }

            Spacer()

            // 删除按钮
            if showDeleteButton {
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(10)
    }

    private var categoryColor: Color {
        switch item.category {
        case "food": return .orange
        case "water": return .blue
        case "medical": return .red
        case "tool": return .gray
        case "material": return .brown
        case "equipment": return .purple
        case "weapon": return .red
        default: return ApocalypseTheme.primary
        }
    }
}

/// 稀有度标签
struct RarityBadge: View {
    let rarity: String

    var body: some View {
        Text(rarityText)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(rarityColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(rarityColor.opacity(0.15))
            )
    }

    private var rarityText: String {
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "少见"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return rarity
        }
    }

    private var rarityColor: Color {
        switch rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }
}

/// AI物品标签
struct AIBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 8))
            Text("AI")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.purple.opacity(0.15))
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        TradeItemCard(
            item: TradeItem(
                itemId: UUID(),
                itemType: "normal",
                itemName: "纯净水",
                quantity: 5,
                category: "water",
                rarity: "common",
                icon: "drop.fill"
            ),
            showDeleteButton: true
        )

        TradeItemCard(
            item: TradeItem(
                itemId: UUID(),
                itemType: "ai",
                itemName: "神秘的古代药剂",
                quantity: 1,
                category: "medical",
                rarity: "epic",
                icon: "flask.fill"
            )
        )
    }
    .padding()
    .background(ApocalypseTheme.background)
}

// MARK: - 迷你物品卡片（用于列表展示）

/// 迷你交易物品卡片 - 用于挂单卡片中的物品展示
struct TradeItemMiniCard: View {
    let item: TradeItem

    /// 分类颜色
    private var categoryColor: Color {
        switch item.category {
        case "food": return .orange
        case "medical": return .red
        case "tool": return .gray
        case "material": return .brown
        case "equipment": return .purple
        case "water": return .blue
        case "weapon": return .yellow
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            // 小图标
            Image(systemName: item.icon ?? "cube.fill")
                .font(.system(size: 10))
                .foregroundColor(categoryColor)

            // 物品名
            Text(item.itemName)
                .font(.system(size: 11))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(1)

            // 数量
            Text("x\(item.quantity)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // AI标记
            if item.itemTypeEnum == .ai {
                Image(systemName: "sparkles")
                    .font(.system(size: 8))
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(categoryColor.opacity(0.1))
        )
    }
}
