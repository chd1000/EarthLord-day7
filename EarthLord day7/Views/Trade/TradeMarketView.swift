//
//  TradeMarketView.swift
//  EarthLord day7
//
//  交易市场页面
//  显示其他玩家的活跃挂单列表
//

import SwiftUI

/// 交易市场视图
struct TradeMarketView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    @ObservedObject var tradeManager: TradeManager
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 当前用户ID
    let currentUserId: UUID?

    /// 搜索文字
    @State private var searchText: String = ""

    /// 选中的分类
    @State private var selectedCategory: String? = nil

    /// 选中的挂单（用于详情页）
    @State private var selectedOffer: DBTradeOffer? = nil

    /// 接受交易确认
    @State private var offerToAccept: DBTradeOffer? = nil

    /// 是否正在接受
    @State private var isAccepting: Bool = false

    /// 错误信息
    @State private var errorMessage: String? = nil

    // MARK: - 计算属性

    /// 筛选后的市场挂单
    private var filteredOffers: [DBTradeOffer] {
        var result = tradeManager.marketOffers

        // 按分类筛选（匹配提供或请求物品的分类）
        if let category = selectedCategory {
            result = result.filter { offer in
                offer.offeringItems.contains { $0.category == category } ||
                (offer.requestingItems?.contains { $0.category == category } ?? false)
            }
        }

        // 按搜索文字筛选
        if !searchText.isEmpty {
            result = result.filter { offer in
                offer.offeringItems.contains { $0.itemName.localizedCaseInsensitiveContains(searchText) } ||
                (offer.requestingItems?.contains { $0.itemName.localizedCaseInsensitiveContains(searchText) } ?? false)
            }
        }

        return result
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // 分类筛选
            categoryFilter
                .padding(.top, 12)

            // 挂单列表
            offerList
                .padding(.top, 12)
        }
        .background(ApocalypseTheme.background)
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(
                offer: offer,
                currentUserId: currentUserId,
                onAccept: {
                    selectedOffer = nil
                    Task {
                        await acceptOffer(offer)
                    }
                }
            )
            .environmentObject(languageManager)
        }
        .confirmationDialog(
            languageManager.localizedString("trade_confirm_accept"),
            isPresented: Binding(
                get: { offerToAccept != nil },
                set: { if !$0 { offerToAccept = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageManager.localizedString("trade_btn_accept"), role: .none) {
                if let offer = offerToAccept {
                    Task {
                        await acceptOffer(offer)
                    }
                }
            }
            Button(languageManager.localizedString("取消"), role: .cancel) {
                offerToAccept = nil
            }
        } message: {
            if let offer = offerToAccept {
                Text(exchangeDescription(for: offer))
            }
        }
        .alert(languageManager.localizedString("错误"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(languageManager.localizedString("确定"), role: .cancel) {}
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .task {
            // 确保库存数据已加载，以便正确构建买家物品
            if inventoryManager.inventoryItems.isEmpty && inventoryManager.aiInventoryItems.isEmpty {
                await inventoryManager.loadInventory()
            }
            if inventoryManager.itemDefinitions.isEmpty {
                await inventoryManager.loadItemDefinitions()
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)
                .font(.system(size: 16))

            TextField(languageManager.localizedString("trade_search_placeholder"), text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(ApocalypseTheme.textPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 分类筛选

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(
                    title: languageManager.localizedString("全部"),
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                CategoryChip(
                    title: languageManager.localizedString("食物"),
                    icon: "fork.knife",
                    color: .orange,
                    isSelected: selectedCategory == "food"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "food"
                    }
                }

                CategoryChip(
                    title: languageManager.localizedString("材料"),
                    icon: "cube.fill",
                    color: .brown,
                    isSelected: selectedCategory == "material"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "material"
                    }
                }

                CategoryChip(
                    title: languageManager.localizedString("工具"),
                    icon: "wrench.and.screwdriver.fill",
                    color: .gray,
                    isSelected: selectedCategory == "tool"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "tool"
                    }
                }

                CategoryChip(
                    title: languageManager.localizedString("医疗"),
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == "medical"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "medical"
                    }
                }

                CategoryChip(
                    title: languageManager.localizedString("装备"),
                    icon: "shield.fill",
                    color: .purple,
                    isSelected: selectedCategory == "equipment"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "equipment"
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            if tradeManager.isLoading && filteredOffers.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 60)
            } else if filteredOffers.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredOffers) { offer in
                        TradeOfferCard(
                            offer: offer,
                            isOwner: false,
                            onAccept: {
                                offerToAccept = offer
                            },
                            onTap: {
                                selectedOffer = offer
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .refreshable {
            await tradeManager.loadMarketOffers()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(languageManager.localizedString("trade_empty_market"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(languageManager.localizedString("trade_empty_market_hint"))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - 交换内容描述

    private func exchangeDescription(for offer: DBTradeOffer) -> String {
        let receivingItems = offer.offeringItems.map { "\($0.itemName) x\($0.quantity)" }.joined(separator: ", ")
        let givingItems: String

        if offer.isOpenOffer {
            givingItems = languageManager.localizedString("trade_open_offer_free")
        } else if let requesting = offer.requestingItems {
            givingItems = requesting.map { "\($0.itemName) x\($0.quantity)" }.joined(separator: ", ")
        } else {
            givingItems = languageManager.localizedString("trade_nothing")
        }

        return String(format: languageManager.localizedString("trade_exchange_description"),
                      receivingItems, givingItems)
    }

    // MARK: - 接受挂单

    private func acceptOffer(_ offer: DBTradeOffer) async {
        isAccepting = true
        do {
            // 确保库存数据已加载
            if inventoryManager.inventoryItems.isEmpty && inventoryManager.aiInventoryItems.isEmpty {
                await inventoryManager.loadInventory()
            }
            if inventoryManager.itemDefinitions.isEmpty {
                await inventoryManager.loadItemDefinitions()
            }

            // 如果挂单有要求的物品，需要从买家库存中找到匹配的物品
            var buyerItems: [TradeItem]? = nil
            if !offer.isOpenOffer, let requestingItems = offer.requestingItems {
                buyerItems = buildBuyerItems(from: requestingItems)

                // 检查是否成功构建了买家物品
                if buyerItems?.isEmpty == true {
                    throw NSError(domain: "Trade", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "无法找到匹配的库存物品"
                    ])
                }
            }

            _ = try await tradeManager.acceptOffer(offerId: offer.id, buyerItems: buyerItems)
        } catch {
            errorMessage = error.localizedDescription
        }
        isAccepting = false
        offerToAccept = nil
    }

    /// 根据卖家请求的物品，从买家库存中构建实际的交易物品
    private func buildBuyerItems(from requestingItems: [TradeItem]) -> [TradeItem] {
        var result: [TradeItem] = []

        for requestedItem in requestingItems {
            if requestedItem.itemTypeEnum == .ai {
                // AI 物品：通过名称匹配，使用 AI 物品的 id
                if let inventoryItem = inventoryManager.aiInventoryItems.first(where: { $0.name == requestedItem.itemName }) {
                    result.append(TradeItem(
                        itemId: inventoryItem.id,
                        itemType: "ai",
                        itemName: inventoryItem.name,
                        quantity: requestedItem.quantity,
                        category: inventoryItem.category,
                        rarity: inventoryItem.rarity,
                        icon: inventoryItem.icon
                    ))
                }
            } else {
                // 普通物品：通过物品定义名称匹配
                // 使用 inventoryItem.id（库存行UUID）作为 itemId，
                // 数据库函数会根据这个 ID 查找实际物品并扣除
                for inventoryItem in inventoryManager.inventoryItems {
                    if let definition = inventoryManager.getDefinition(for: inventoryItem.itemId),
                       definition.name == requestedItem.itemName {
                        result.append(TradeItem(
                            itemId: inventoryItem.id,  // 使用库存行ID
                            itemType: "normal",
                            itemName: definition.name,
                            quantity: requestedItem.quantity,
                            category: definition.category,
                            rarity: definition.rarity,
                            icon: definition.icon
                        ))
                        break  // 找到一个匹配的就够了
                    }
                }
            }
        }

        return result
    }
}

// MARK: - 预览

#Preview {
    TradeMarketView(
        tradeManager: TradeManager.shared,
        currentUserId: UUID()
    )
    .environmentObject(LanguageManager.shared)
}
