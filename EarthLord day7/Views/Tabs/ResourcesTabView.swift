//
//  ResourcesTabView.swift
//  EarthLord day7
//
//  资源模块主入口页面
//  包含 POI、背包、已购、领地、交易 五个分段
//

import SwiftUI

/// 资源分段枚举
enum ResourceSegment: String, CaseIterable {
    case poi = "POI"
    case backpack = "backpack"
    case purchased = "purchased"
    case territory = "territory"
    case trade = "trade"

    /// 获取本地化显示名称
    func localizedName(_ languageManager: LanguageManager) -> String {
        switch self {
        case .poi: return "POI"
        case .backpack: return languageManager.localizedString("背包")
        case .purchased: return languageManager.localizedString("已购")
        case .territory: return languageManager.localizedString("领地")
        case .trade: return languageManager.localizedString("交易")
        }
    }
}

struct ResourcesTabView: View {

    // MARK: - 环境
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - 状态

    /// 当前选中的分段
    @State private var selectedSegment: ResourceSegment = .poi

    /// 交易开关状态（假数据）
    @State private var isTradeEnabled: Bool = false

    // MARK: - 初始化

    init() {
        // 配置分段选择器外观
        let appearance = UISegmentedControl.appearance()

        // 未选中状态的文字颜色（更亮的白色）
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ], for: .normal)

        // 选中状态的文字颜色（黑色，因为背景是白色）
        appearance.setTitleTextAttributes([
            .foregroundColor: UIColor.black
        ], for: .selected)
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分段选择器
                segmentPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // 分隔线
                Divider()
                    .background(ApocalypseTheme.textMuted.opacity(0.3))

                // 内容区域
                contentView
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(languageManager.localizedString("附近地点"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    tradeToggle
                }
            }
        }
    }

    // MARK: - 分段选择器

    /// 分段选择器
    private var segmentPicker: some View {
        Picker("分段", selection: $selectedSegment) {
            ForEach(ResourceSegment.allCases, id: \.self) { segment in
                Text(segment.localizedName(languageManager))
                    .tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 交易开关

    /// 交易开关
    private var tradeToggle: some View {
        HStack(spacing: 6) {
            Text(languageManager.localizedString("交易"))
                .font(.system(size: 13))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Toggle("", isOn: $isTradeEnabled)
                .labelsHidden()
                .scaleEffect(0.8)
                .tint(ApocalypseTheme.primary)
        }
    }

    // MARK: - 内容区域

    /// 根据选中分段显示对应内容
    @ViewBuilder
    private var contentView: some View {
        switch selectedSegment {
        case .poi:
            POIListView()

        case .backpack:
            BackpackView()

        case .purchased:
            placeholderView(
                icon: "bag.fill",
                title: languageManager.localizedString("已购物品"),
                subtitle: languageManager.localizedString("功能开发中")
            )

        case .territory:
            placeholderView(
                icon: "flag.fill",
                title: languageManager.localizedString("领地资源"),
                subtitle: languageManager.localizedString("功能开发中")
            )

        case .trade:
            placeholderView(
                icon: "arrow.triangle.2.circlepath",
                title: languageManager.localizedString("交易市场"),
                subtitle: languageManager.localizedString("功能开发中")
            )
        }
    }

    // MARK: - 占位视图

    /// 占位视图（功能开发中）
    private func placeholderView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // 图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.cardBackground)
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }

            // 标题
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 副标题
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textSecondary)

            // 开发中标签
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 12))

                Text(languageManager.localizedString("敬请期待"))
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(ApocalypseTheme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(ApocalypseTheme.primary.opacity(0.15))
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ApocalypseTheme.background)
    }
}

// MARK: - 预览

#Preview {
    ResourcesTabView()
        .environmentObject(LanguageManager.shared)
}
