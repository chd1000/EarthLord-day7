//
//  ScavengeResultView.swift
//  EarthLord day7
//
//  搜刮结果视图
//  展示搜刮获得的物品列表
//

import SwiftUI

/// 搜刮结果视图
struct ScavengeResultView: View {

    // MARK: - 属性

    /// 搜刮结果
    let result: ScavengeResult

    /// 关闭动作
    let onDismiss: () -> Void

    /// 物品显示动画状态
    @State private var showItems: [Bool] = []

    /// 展开的物品索引（用于显示故事）
    @State private var expandedItemIndex: Int? = nil

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 24) {
            // 成功图标
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.orange.opacity(0.3), .yellow.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)
                }

                HStack(spacing: 4) {
                    Text("搜刮成功!")
                        .font(.title2)
                        .fontWeight(.bold)

                    // AI 生成标记
                    if result.isAIGenerated {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

                Text(result.poiName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            // 获得物品列表
            if result.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("这里什么都没有...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 30)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("获得物品")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()

                        if result.isAIGenerated {
                            Text("AI 生成")
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                        ScavengedItemRow(
                            item: item,
                            isExpanded: expandedItemIndex == index,
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    if expandedItemIndex == index {
                                        expandedItemIndex = nil
                                    } else {
                                        expandedItemIndex = index
                                    }
                                }
                            }
                        )
                        .opacity(showItems.indices.contains(index) && showItems[index] ? 1 : 0)
                        .offset(x: showItems.indices.contains(index) && showItems[index] ? 0 : -30)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.15), value: showItems)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }

            Spacer()

            // 确认按钮
            Button(action: onDismiss) {
                Text("太棒了!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .onAppear {
            // 初始化动画状态
            showItems = Array(repeating: false, count: result.items.count)

            // 触发物品显示动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                for index in result.items.indices {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                        if showItems.indices.contains(index) {
                            showItems[index] = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 物品行视图

/// 单个搜刮物品行
struct ScavengedItemRow: View {

    let item: ScavengeResult.ScavengedItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主内容行
            HStack(spacing: 12) {
                // 物品图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(rarityColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                        .foregroundColor(rarityColor)
                }

                // 物品信息
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        // AI 生成标记
                        if item.isAIGenerated {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                                .foregroundColor(.purple)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(rarityText)
                            .font(.caption2)
                            .foregroundColor(rarityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rarityColor.opacity(0.1))
                            .cornerRadius(4)

                        Text(categoryText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 数量和展开指示器
                HStack(spacing: 8) {
                    Text("x\(item.quantity)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if item.story != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)

            // 故事展开区域
            if isExpanded, let story = item.story {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.horizontal, 10)

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "quote.opening")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(story)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if item.story != nil {
                onTap()
            }
        }
    }

    // MARK: - 计算属性

    /// 稀有度颜色
    private var rarityColor: Color {
        switch item.rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    /// 稀有度文本
    private var rarityText: String {
        switch item.rarity {
        case "common": return "普通"
        case "uncommon": return "少见"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return "未知"
        }
    }

    /// 类别文本
    private var categoryText: String {
        switch item.category {
        case "food": return "食物"
        case "medical": return "医疗"
        case "tool": return "工具"
        case "material": return "材料"
        case "equipment": return "装备"
        case "water": return "水类"
        case "weapon": return "武器"
        default: return "杂项"
        }
    }
}

// MARK: - 预览

#Preview {
    ScavengeResultView(
        result: ScavengeResult(
            poiId: UUID(),
            poiName: "废弃的中心医院",
            poiType: .hospital,
            items: [
                ScavengeResult.ScavengedItem(
                    itemId: "bandage",
                    name: "染血的急救绷带",
                    quantity: 2,
                    rarity: "uncommon",
                    icon: "cross.case.fill",
                    category: "medical",
                    story: "医院急诊室的储物柜里找到的，上面还残留着干涸的血迹",
                    isAIGenerated: true
                ),
                ScavengeResult.ScavengedItem(
                    itemId: "first_aid_kit",
                    name: "军用急救包",
                    quantity: 1,
                    rarity: "epic",
                    icon: "cross.case.fill",
                    category: "medical",
                    story: "这是一个标准的军用急救包，里面的物资保存完好",
                    isAIGenerated: true
                ),
                ScavengeResult.ScavengedItem(
                    itemId: "legendary_item",
                    name: "神秘药剂",
                    quantity: 1,
                    rarity: "legendary",
                    icon: "pills.fill",
                    category: "medical",
                    story: "实验室深处发现的未知药剂，散发着诡异的光芒",
                    isAIGenerated: true
                )
            ],
            isAIGenerated: true
        ),
        onDismiss: {}
    )
}
