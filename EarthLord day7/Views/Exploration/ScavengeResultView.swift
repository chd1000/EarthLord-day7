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

                Text("搜刮成功!")
                    .font(.title2)
                    .fontWeight(.bold)

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
                    Text("获得物品")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                        ScavengedItemRow(item: item)
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

    var body: some View {
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
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

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

            // 数量
            Text("x\(item.quantity)")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - 计算属性

    /// 稀有度颜色
    private var rarityColor: Color {
        switch item.rarity {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        default: return .gray
        }
    }

    /// 稀有度文本
    private var rarityText: String {
        switch item.rarity {
        case "common": return "普通"
        case "rare": return "稀有"
        case "epic": return "史诗"
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
                    name: "绷带",
                    quantity: 2,
                    rarity: "common",
                    icon: "cross.case.fill",
                    category: "medical"
                ),
                ScavengeResult.ScavengedItem(
                    itemId: "first_aid_kit",
                    name: "急救包",
                    quantity: 1,
                    rarity: "rare",
                    icon: "cross.case.fill",
                    category: "medical"
                ),
                ScavengeResult.ScavengedItem(
                    itemId: "canned_food",
                    name: "罐头食品",
                    quantity: 1,
                    rarity: "common",
                    icon: "takeoutbag.and.cup.and.straw.fill",
                    category: "food"
                )
            ]
        ),
        onDismiss: {}
    )
}
