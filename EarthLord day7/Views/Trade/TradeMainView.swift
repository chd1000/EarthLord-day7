//
//  TradeMainView.swift
//  EarthLord day7
//
//  交易主页面
//  使用 Segmented Picker 切换市场、我的挂单、历史三个子页面
//

import SwiftUI
import Supabase

/// 交易子页面枚举
enum TradeTab: String, CaseIterable {
    case market = "market"
    case myOffers = "my_offers"
    case history = "history"

    /// 获取本地化显示名称
    func localizedName(_ languageManager: LanguageManager) -> String {
        switch self {
        case .market: return languageManager.localizedString("trade_tab_market")
        case .myOffers: return languageManager.localizedString("trade_tab_my_offers")
        case .history: return languageManager.localizedString("trade_tab_history")
        }
    }

    /// 图标
    var icon: String {
        switch self {
        case .market: return "storefront"
        case .myOffers: return "doc.text"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// 交易主视图
struct TradeMainView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    @StateObject private var tradeManager = TradeManager.shared

    /// 当前选中的标签页
    @State private var selectedTab: TradeTab = .market

    /// 显示创建挂单页面
    @State private var showCreateOffer: Bool = false

    /// 当前用户ID
    @State private var currentUserId: UUID? = nil

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 标签页选择器
            tabPicker
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // 内容区域
            contentView
        }
        .background(ApocalypseTheme.background)
        .overlay(alignment: .bottomTrailing) {
            // 浮动添加按钮
            floatingAddButton
        }
        .sheet(isPresented: $showCreateOffer) {
            CreateTradeOfferView(tradeManager: tradeManager)
                .environmentObject(languageManager)
        }
        .onAppear {
            loadData()
        }
    }

    // MARK: - 标签页选择器

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(TradeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))

                            Text(tab.localizedName(languageManager))
                                .font(.system(size: 14, weight: .medium))

                            // 角标（我的挂单）
                            if tab == .myOffers && tradeManager.activeMyOffersCount > 0 {
                                Text("\(tradeManager.activeMyOffersCount)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(ApocalypseTheme.primary)
                                    )
                            }

                            // 角标（历史 - 待评价）
                            if tab == .history, let userId = currentUserId {
                                let pendingCount = tradeManager.pendingRatingCount(userId: userId)
                                if pendingCount > 0 {
                                    Text("\(pendingCount)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(ApocalypseTheme.warning)
                                        )
                                }
                            }
                        }
                        .foregroundColor(selectedTab == tab ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                        // 下划线指示器
                        Rectangle()
                            .fill(selectedTab == tab ? ApocalypseTheme.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - 内容区域

    @ViewBuilder
    private var contentView: some View {
        TabView(selection: $selectedTab) {
            TradeMarketView(
                tradeManager: tradeManager,
                currentUserId: currentUserId
            )
            .tag(TradeTab.market)

            MyTradeOffersView(
                tradeManager: tradeManager,
                currentUserId: currentUserId
            )
            .tag(TradeTab.myOffers)

            TradeHistoryView(
                tradeManager: tradeManager,
                currentUserId: currentUserId
            )
            .tag(TradeTab.history)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: - 浮动添加按钮

    private var floatingAddButton: some View {
        Button {
            showCreateOffer = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(ApocalypseTheme.primary)
                        .shadow(color: ApocalypseTheme.primary.opacity(0.4), radius: 8, y: 4)
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - 加载数据

    private func loadData() {
        Task {
            // 获取当前用户ID
            do {
                let session = try await supabase.auth.session
                currentUserId = session.user.id
            } catch {
                print("❌ 获取用户ID失败: \(error)")
            }

            // 加载所有交易数据
            await tradeManager.loadAll()
        }
    }
}

// MARK: - 预览

#Preview {
    TradeMainView()
        .environmentObject(LanguageManager.shared)
}
