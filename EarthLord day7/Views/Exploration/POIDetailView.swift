//
//  POIDetailView.swift
//  EarthLord day7
//
//  POI 详情页面
//  显示兴趣点的详细信息、操作按钮
//

import SwiftUI

struct POIDetailView: View {

    // MARK: - 属性

    /// POI 数据
    let poi: POI

    /// 关闭回调
    var onDismiss: (() -> Void)?

    // MARK: - 状态

    /// 是否显示探索结果
    @State private var showExplorationResult: Bool = false

    /// 是否正在搜寻
    @State private var isSearching: Bool = false

    /// 假数据：距离
    private let mockDistance: Int = 350

    /// 假数据：来源
    private let mockSource: String = "地图数据"

    // MARK: - 计算属性

    /// POI 类型颜色
    private var typeColor: Color {
        switch poi.type {
        case .hospital: return .red
        case .supermarket: return .green
        case .factory: return .gray
        case .pharmacy: return .purple
        case .gasStation: return .orange
        case .warehouse: return .brown
        case .house: return .cyan
        case .police: return .blue
        case .military: return .indigo
        }
    }

    /// 渐变色（基于类型颜色）
    private var gradientColors: [Color] {
        [typeColor.opacity(0.8), typeColor.opacity(0.4), ApocalypseTheme.background]
    }

    /// 危险等级文字
    private var dangerLevelText: String {
        switch poi.dangerLevel {
        case 1: return "安全"
        case 2: return "低危"
        case 3: return "中危"
        case 4, 5: return "高危"
        default: return "未知"
        }
    }

    /// 危险等级颜色
    private var dangerLevelColor: Color {
        switch poi.dangerLevel {
        case 1: return ApocalypseTheme.success
        case 2: return .cyan
        case 3: return ApocalypseTheme.warning
        case 4, 5: return ApocalypseTheme.danger
        default: return ApocalypseTheme.textMuted
        }
    }

    /// 物资状态文字
    private var lootStatusText: String {
        switch poi.status {
        case .undiscovered: return "未知"
        case .discovered: return poi.hasLoot ? "有物资" : "无物资"
        case .looted: return "已清空"
        }
    }

    /// 物资状态颜色
    private var lootStatusColor: Color {
        switch poi.status {
        case .undiscovered: return ApocalypseTheme.textMuted
        case .discovered: return poi.hasLoot ? ApocalypseTheme.success : ApocalypseTheme.warning
        case .looted: return ApocalypseTheme.danger
        }
    }

    /// 是否可以搜寻
    private var canSearch: Bool {
        poi.status != .looted
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // 顶部大图区域
                    headerSection

                    // 信息区域
                    infoSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // 描述
                    descriptionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // 操作按钮区域
                    actionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExplorationResult) {
            ExplorationResultView(result: MockExplorationData.mockExplorationRewardResult)
        }
    }

    // MARK: - 顶部大图区域

    /// 顶部大图区域
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // 渐变背景
            LinearGradient(
                colors: gradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)

            // 大图标
            VStack {
                Spacer()

                Image(systemName: poi.iconName)
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                Spacer()
            }
            .frame(height: 200)

            // 底部遮罩 + 名称
            VStack(spacing: 6) {
                Spacer()

                // POI 名称
                Text(poi.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                // POI 类型
                HStack(spacing: 8) {
                    Image(systemName: poi.iconName)
                        .font(.system(size: 14))

                    Text(poi.typeDisplayName)
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - 信息区域

    /// 信息卡片区域
    private var infoSection: some View {
        VStack(spacing: 12) {
            // 第一行：距离 + 物资状态
            HStack(spacing: 12) {
                // 距离
                InfoCard(
                    icon: "location.fill",
                    iconColor: ApocalypseTheme.info,
                    title: "距离",
                    value: "\(mockDistance)米"
                )

                // 物资状态
                InfoCard(
                    icon: "cube.box.fill",
                    iconColor: lootStatusColor,
                    title: "物资状态",
                    value: lootStatusText,
                    valueColor: lootStatusColor
                )
            }

            // 第二行：危险等级 + 来源
            HStack(spacing: 12) {
                // 危险等级
                InfoCard(
                    icon: "exclamationmark.shield.fill",
                    iconColor: dangerLevelColor,
                    title: "危险等级",
                    value: dangerLevelText,
                    valueColor: dangerLevelColor
                )

                // 来源
                InfoCard(
                    icon: "doc.text.fill",
                    iconColor: ApocalypseTheme.textSecondary,
                    title: "来源",
                    value: mockSource
                )
            }
        }
    }

    // MARK: - 描述区域

    /// 描述区域
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("描述")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(poi.description)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 操作按钮区域

    /// 操作按钮区域
    private var actionSection: some View {
        VStack(spacing: 14) {
            // 主按钮：搜寻此 POI
            Button {
                performSearch()
            } label: {
                HStack(spacing: 10) {
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)

                        Text("搜寻中...")
                            .font(.system(size: 17, weight: .semibold))
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))

                        Text("搜寻此POI")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if canSearch {
                            LinearGradient(
                                colors: [ApocalypseTheme.primary, ApocalypseTheme.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.gray.opacity(0.5)
                        }
                    }
                )
                .cornerRadius(12)
            }
            .disabled(!canSearch || isSearching)

            // 已清空提示
            if !canSearch {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))

                    Text("此地点已被搜空，无法再次搜寻")
                        .font(.system(size: 13))
                }
                .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 次要按钮行
            HStack(spacing: 12) {
                // 标记已发现
                SecondaryActionButton(
                    icon: "checkmark.circle",
                    title: "标记已发现",
                    isActive: poi.status == .discovered
                ) {
                    handleMarkDiscovered()
                }

                // 标记无物资
                SecondaryActionButton(
                    icon: "xmark.circle",
                    title: "标记无物资",
                    isActive: !poi.hasLoot && poi.status == .discovered
                ) {
                    handleMarkNoLoot()
                }
            }
        }
    }

    // MARK: - 方法

    /// 执行搜寻
    private func performSearch() {
        guard canSearch else { return }

        isSearching = true

        // 模拟搜寻过程（2秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSearching = false
            showExplorationResult = true
        }
    }

    /// 标记已发现
    private func handleMarkDiscovered() {
        print("标记已发现: \(poi.name)")
        // TODO: 更新 POI 状态
    }

    /// 标记无物资
    private func handleMarkNoLoot() {
        print("标记无物资: \(poi.name)")
        // TODO: 更新 POI 状态
    }
}

// MARK: - 信息卡片组件

/// 信息卡片
struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var valueColor: Color = ApocalypseTheme.textPrimary

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(valueColor)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

// MARK: - 次要按钮组件

/// 次要操作按钮
struct SecondaryActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isActive ? "\(icon).fill" : icon)
                    .font(.system(size: 14))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isActive ? ApocalypseTheme.success : ApocalypseTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ApocalypseTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? ApocalypseTheme.success.opacity(0.5) : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 预览

#Preview("已发现有物资") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.mockPOIs[0])
    }
}

#Preview("已被搜空") {
    NavigationStack {
        POIDetailView(poi: MockExplorationData.mockPOIs[1])
    }
}
