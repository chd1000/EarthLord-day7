//
//  ExplorationResultView.swift
//  EarthLord day7
//
//  探索结果弹窗页面
//  显示探索统计数据和获得的物品奖励
//

import SwiftUI

struct ExplorationResultView: View {

    // MARK: - 属性

    /// 探索结果数据（成功时有值）
    let result: ExplorationResult?

    /// 错误信息（失败时有值）
    var errorMessage: String? = nil

    /// 重试回调
    var onRetry: (() -> Void)? = nil

    /// 环境变量：关闭页面
    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    /// 动画状态：是否显示内容
    @State private var showContent: Bool = false

    /// 动画状态：是否显示物品
    @State private var showItems: Bool = false

    /// 动画数字：行走距离
    @State private var animatedWalkDistance: Double = 0

    /// 动画数字：探索面积
    @State private var animatedExploredArea: Double = 0

    /// 动画数字：发现POI
    @State private var animatedPOICount: Int = 0

    /// 是否为错误状态
    private var isError: Bool {
        result == nil && errorMessage != nil
    }

    // MARK: - 计算属性

    /// 格式化动画行走距离
    private var formattedAnimatedWalkDistance: String {
        if animatedWalkDistance >= 1000 {
            return String(format: "%.2f km", animatedWalkDistance / 1000)
        } else {
            return String(format: "%.0f m", animatedWalkDistance)
        }
    }

    /// 格式化动画探索面积
    private var formattedAnimatedExploredArea: String {
        if animatedExploredArea >= 1000000 {
            return String(format: "%.2f km²", animatedExploredArea / 1000000)
        } else {
            return String(format: "%.0f m²", animatedExploredArea)
        }
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                ApocalypseTheme.background
                    .ignoresSafeArea()

                if isError {
                    // 错误状态
                    errorStateView
                } else if let result = result {
                    // 成功状态
                    ScrollView {
                        VStack(spacing: 24) {
                            // 成就标题
                            achievementHeader
                                .opacity(showContent ? 1 : 0)
                                .scaleEffect(showContent ? 1 : 0.8)

                            // 统计数据卡片
                            statsCard
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)

                            // 奖励物品卡片
                            rewardsCard
                                .opacity(showItems ? 1 : 0)
                                .offset(y: showItems ? 0 : 20)

                            // 确认按钮
                            confirmButton
                                .opacity(showItems ? 1 : 0)
                                .offset(y: showItems ? 0 : 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .onAppear {
                        startAnimations(with: result)
                    }
                }
            }
            .navigationTitle(isError ? "探索失败" : "探索报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    /// 启动动画
    private func startAnimations(with result: ExplorationResult) {
        // 入场动画
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showContent = true
        }
        // 延迟显示物品
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showItems = true
            }
        }
        // 延迟启动数字动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // 行走距离动画
            withAnimation(.easeOut(duration: 1.0)) {
                animatedWalkDistance = result.stats.walkDistanceThisTime
            }
            // 探索面积动画（稍微延迟）
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) {
                animatedExploredArea = result.stats.exploredAreaThisTime
            }
            // POI 数量动画（再延迟）
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedPOICount = result.stats.discoveredPOICount
            }
        }
    }

    // MARK: - 错误状态视图

    /// 错误状态视图
    private var errorStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 错误图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.danger.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.danger)
            }

            // 错误标题
            Text("探索失败")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(errorMessage ?? "未知错误")
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 重试按钮
            if let onRetry = onRetry {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))

                        Text("重试")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 160)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.top, 8)
            }

            // 关闭按钮
            Button {
                dismiss()
            } label: {
                Text("返回")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - 成就标题

    /// 成就标题区域（带仪式感）
    private var achievementHeader: some View {
        VStack(spacing: 16) {
            // 大图标（带光晕效果）
            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ApocalypseTheme.primary.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                // 内层圆
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: ApocalypseTheme.primary.opacity(0.5), radius: 15, x: 0, y: 5)

                // 图标
                Image(systemName: "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 大标题
            Text("探索完成！")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text("本次探索已记录，物资已添加到背包")
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    // MARK: - 统计数据卡片

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ApocalypseTheme.info)

                Text("探索统计")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 探索时长
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(result?.stats.formattedDuration ?? "--")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 行走距离
            StatRow(
                icon: "figure.walk",
                iconColor: .cyan,
                title: "行走距离",
                thisTime: formattedAnimatedWalkDistance,
                total: result?.stats.formattedWalkDistanceTotal ?? "--",
                rank: result?.stats.walkDistanceRank ?? 0
            )

            // 探索面积
            StatRow(
                icon: "square.dashed",
                iconColor: .green,
                title: "探索面积",
                thisTime: formattedAnimatedExploredArea,
                total: result?.stats.formattedExploredAreaTotal ?? "--",
                rank: result?.stats.exploredAreaRank ?? 0
            )

            // 发现POI
            HStack {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                }

                // 标题
                Text("发现地点")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 数值
                HStack(spacing: 4) {
                    Text("本次 ")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text("+\(animatedPOICount)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(ApocalypseTheme.primary)
                        .contentTransition(.numericText())
                    Text(" / 累计 \(result?.stats.totalPOICount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 奖励物品卡片

    /// 奖励物品卡片
    private var rewardsCard: some View {
        VStack(spacing: 14) {
            // 标题
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(ApocalypseTheme.warning)

                Text("获得物品")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 物品数量
                Text("\(result?.obtainedItems.count ?? 0) 种")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物品列表
            VStack(spacing: 10) {
                ForEach(Array((result?.obtainedItems ?? []).enumerated()), id: \.offset) { index, item in
                    if let definition = MockExplorationData.getItemDefinition(for: item.itemId) {
                        RewardItemRow(
                            name: definition.name,
                            quantity: item.quantity,
                            quality: item.quality,
                            icon: definition.categoryIconName,
                            color: categoryColor(definition.category),
                            delay: Double(index) * 0.2
                        )
                    }
                }
            }

            // 底部提示
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.success)

                Text("已添加到背包")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.success)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 确认按钮

    /// 确认按钮
    private var confirmButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))

                Text("确认收下")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [ApocalypseTheme.success, ApocalypseTheme.success.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: ApocalypseTheme.success.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - 辅助方法

    /// 分类颜色
    private func categoryColor(_ category: ItemCategory) -> Color {
        switch category {
        case .water: return .cyan
        case .food: return .orange
        case .medical: return .red
        case .material: return .brown
        case .tool: return .gray
        case .weapon: return .purple
        case .clothing: return .blue
        case .misc: return .secondary
        }
    }
}

// MARK: - 统计行组件

/// 统计数据行
struct StatRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let thisTime: String
    let total: String
    let rank: Int

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }

            // 标题
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Spacer()

            // 数值区域
            VStack(alignment: .trailing, spacing: 2) {
                // 本次
                HStack(spacing: 4) {
                    Text("本次")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)
                    Text(thisTime)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                }

                // 累计 + 排名
                HStack(spacing: 6) {
                    Text("累计 \(total)")
                        .font(.system(size: 11))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    // 排名标签
                    Text("#\(rank)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.success.opacity(0.15))
                        )
                }
            }
        }
    }
}

// MARK: - 奖励物品行组件

/// 奖励物品行
struct RewardItemRow: View {
    let name: String
    let quantity: Int
    let quality: ItemQuality?
    let icon: String
    let color: Color
    let delay: Double

    @State private var showRow: Bool = false
    @State private var showCheck: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            // 名称
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 品质（如有）
            if let quality = quality {
                Text(quality.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(qualityColor(quality))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(qualityColor(quality).opacity(0.15))
                    )
            }

            Spacer()

            // 数量
            Text("+\(quantity)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(ApocalypseTheme.primary)

            // 绿色对勾
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(ApocalypseTheme.success)
                .opacity(showCheck ? 1 : 0)
                .scaleEffect(showCheck ? 1 : 0.5)
        }
        .padding(.vertical, 6)
        .opacity(showRow ? 1 : 0)
        .offset(x: showRow ? 0 : -20)
        .onAppear {
            // 延迟显示行动画
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showRow = true
                }
            }
            // 延迟显示对勾动画（在行出现后再显示）
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showCheck = true
                }
            }
        }
    }

    /// 品质颜色
    private func qualityColor(_ quality: ItemQuality) -> Color {
        switch quality {
        case .broken: return .gray
        case .worn: return .brown
        case .normal: return .secondary
        case .good: return .green
        case .excellent: return .blue
        }
    }
}

// MARK: - 预览

#Preview("成功状态") {
    ExplorationResultView(result: MockExplorationData.mockExplorationResult)
}

#Preview("错误状态") {
    ExplorationResultView(
        result: nil,
        errorMessage: "网络连接失败，请检查网络设置后重试",
        onRetry: {
            print("重试探索")
        }
    )
}
