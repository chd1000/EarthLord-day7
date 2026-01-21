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
    let result: ExplorationRewardResult?

    /// 错误信息（失败时有值）
    var errorMessage: String? = nil

    /// 重试回调
    var onRetry: (() -> Void)? = nil

    /// 环境变量：关闭页面
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - 状态

    /// 动画状态：是否显示内容
    @State private var showContent: Bool = false

    /// 动画状态：是否显示物品
    @State private var showItems: Bool = false

    /// 动画数字：行走距离
    @State private var animatedWalkDistance: Double = 0

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

    /// 格式化时长
    private var formattedDuration: String {
        guard let result = result else { return "--" }
        let minutes = Int(result.duration) / 60
        let seconds = Int(result.duration) % 60
        if minutes > 0 {
            return "\(minutes) \(languageManager.localizedString("分")) \(seconds) \(languageManager.localizedString("秒"))"
        } else {
            return "\(seconds) \(languageManager.localizedString("秒"))"
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
            .navigationTitle(isError ? languageManager.localizedString("探索失败") : languageManager.localizedString("探索报告"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.localizedString("关闭")) {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    /// 启动动画
    private func startAnimations(with result: ExplorationRewardResult) {
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
                animatedWalkDistance = result.distance
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
            Text(languageManager.localizedString("探索失败"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 错误信息
            Text(errorMessage ?? languageManager.localizedString("未知错误"))
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

                        Text(languageManager.localizedString("重试"))
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
                Text(languageManager.localizedString("返回"))
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
                            colors: [tierColor.opacity(0.3), Color.clear],
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
                            colors: [tierColor, tierColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: tierColor.opacity(0.5), radius: 15, x: 0, y: 5)

                // 图标
                Image(systemName: result?.rewardTier.icon ?? "map.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            // 大标题
            Text(languageManager.localizedString("探索完成！"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 奖励等级
            HStack(spacing: 8) {
                Text(languageManager.localizedString("奖励等级"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text(localizedTierName(result?.rewardTier))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tierColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(tierColor.opacity(0.15))
                    )
            }

            // 副标题
            Text(result?.rewardTier == RewardTier.none ? languageManager.localizedString("行走距离不足200米，无法获得奖励") : languageManager.localizedString("物资已添加到背包"))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    /// 本地化奖励等级名称
    private func localizedTierName(_ tier: RewardTier?) -> String {
        guard let tier = tier else { return languageManager.localizedString("无奖励") }
        switch tier {
        case .none: return languageManager.localizedString("无奖励")
        case .bronze: return languageManager.localizedString("铜级")
        case .silver: return languageManager.localizedString("银级")
        case .gold: return languageManager.localizedString("金级")
        case .diamond: return languageManager.localizedString("钻石级")
        }
    }

    /// 奖励等级对应颜色
    private var tierColor: Color {
        guard let tier = result?.rewardTier else { return ApocalypseTheme.primary }
        switch tier {
        case .none: return .gray
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .diamond: return .cyan
        }
    }

    // MARK: - 统计数据卡片

    /// 统计数据卡片
    private var statsCard: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ApocalypseTheme.info)

                Text(languageManager.localizedString("探索统计"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 探索时长
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                    Text(formattedDuration)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 行走距离
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "figure.walk")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                }

                // 标题
                Text(languageManager.localizedString("行走距离"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 数值
                Text(formattedAnimatedWalkDistance)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .contentTransition(.numericText())
            }

            // 奖励等级说明
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: result?.rewardTier.icon ?? "medal")
                        .font(.system(size: 14))
                        .foregroundColor(tierColor)
                }

                // 标题
                Text(languageManager.localizedString("奖励等级"))
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Spacer()

                // 等级
                Text(localizedTierName(result?.rewardTier))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(tierColor)
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

                Text(languageManager.localizedString("获得物品"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 物品数量
                Text("\(result?.rewardedItems.count ?? 0) \(languageManager.localizedString("种"))")
                    .font(.system(size: 13))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 分隔线
            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.3))

            // 物品列表
            if let items = result?.rewardedItems, !items.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        RewardItemRowNew(
                            name: item.name,
                            quantity: item.quantity,
                            rarity: item.rarity,
                            icon: item.icon,
                            category: item.category,
                            delay: Double(index) * 0.2
                        )
                    }
                }

                // 底部提示
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.success)

                    Text(languageManager.localizedString("已添加到背包"))
                        .font(.system(size: 13))
                        .foregroundColor(ApocalypseTheme.success)
                }
                .padding(.top, 4)
            } else {
                // 无奖励状态
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(languageManager.localizedString("行走距离不足，没有获得物品"))
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textMuted)

                    Text(languageManager.localizedString("走满200米可获得铜级奖励"))
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.vertical, 20)
            }
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

                Text(languageManager.localizedString("确认收下"))
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
}

// MARK: - 奖励物品行组件（新版）

/// 奖励物品行
struct RewardItemRowNew: View {
    @EnvironmentObject private var languageManager: LanguageManager

    let name: String
    let quantity: Int
    let rarity: String
    let icon: String
    let category: String
    let delay: Double

    @State private var showRow: Bool = false
    @State private var showCheck: Bool = false

    /// 分类颜色
    private var categoryColor: Color {
        switch category {
        case "food": return .orange
        case "medical": return .red
        case "tool": return .gray
        case "material": return .brown
        case "equipment": return .purple
        default: return .secondary
        }
    }

    /// 稀有度颜色
    private var rarityColor: Color {
        switch rarity {
        case "common": return .gray
        case "rare": return .blue
        case "epic": return .purple
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(categoryColor)
            }

            // 名称
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 稀有度标签
            Text(rarityDisplayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(rarityColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(rarityColor.opacity(0.15))
                )

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

    /// 稀有度显示名称
    private var rarityDisplayName: String {
        switch rarity {
        case "common": return languageManager.localizedString("普通")
        case "rare": return languageManager.localizedString("稀有")
        case "epic": return languageManager.localizedString("史诗")
        default: return rarity
        }
    }
}

// MARK: - 预览

#Preview("成功状态 - 有奖励") {
    ExplorationResultView(
        result: ExplorationRewardResult(
            sessionId: UUID(),
            distance: 850,
            duration: 600,
            rewardTier: .silver,
            rewardedItems: [
                .init(itemId: "water_bottle", name: "纯净水", quantity: 2, rarity: "common", icon: "drop.fill", category: "food"),
                .init(itemId: "bandage", name: "绷带", quantity: 1, rarity: "common", icon: "bandage", category: "medical")
            ]
        )
    )
    .environmentObject(LanguageManager.shared)
}

#Preview("成功状态 - 无奖励") {
    ExplorationResultView(
        result: ExplorationRewardResult(
            sessionId: UUID(),
            distance: 100,
            duration: 120,
            rewardTier: .none,
            rewardedItems: []
        )
    )
    .environmentObject(LanguageManager.shared)
}

#Preview("错误状态") {
    ExplorationResultView(
        result: nil,
        errorMessage: "网络连接失败，请检查网络设置后重试",
        onRetry: {
            print("重试探索")
        }
    )
    .environmentObject(LanguageManager.shared)
}
