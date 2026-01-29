//
//  ItemPickerView.swift
//  EarthLord day7
//
//  物品选择器组件
//  用于选择要交易的物品（从背包选择或指定请求物品）
//

import SwiftUI

/// 物品选择器
struct ItemPickerView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    /// 是否是请求模式（选择想要的物品，而非背包已有物品）
    let isRequestMode: Bool

    /// 已选择的物品（用于排除已选）
    let excludedItemIds: Set<UUID>

    /// 选择回调
    let onSelect: ([TradeItem]) -> Void

    // MARK: - 状态

    @StateObject private var inventoryManager = InventoryManager.shared

    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedItems: [SelectedItem] = []

    /// 选中的物品及数量
    struct SelectedItem: Identifiable {
        let id: UUID
        let item: Any  // DBInventoryItem 或 DBAIInventoryItem
        var quantity: Int
        let maxQuantity: Int
        let isAI: Bool
    }

    // MARK: - 计算属性

    /// 筛选后的普通物品（仅用于出售模式）
    private var filteredItems: [DBInventoryItem] {
        guard !isRequestMode else { return [] }

        var result = inventoryManager.inventoryItems.filter { !excludedItemIds.contains($0.id) }

        if let category = selectedCategory {
            result = result.filter { item in
                inventoryManager.getDefinition(for: item.itemId)?.category == category
            }
        }

        if !searchText.isEmpty {
            result = result.filter { item in
                inventoryManager.getDefinition(for: item.itemId)?.name
                    .localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return result
    }

    /// 筛选后的 AI 物品（仅用于出售模式）
    private var filteredAIItems: [DBAIInventoryItem] {
        guard !isRequestMode else { return [] }

        var result = inventoryManager.aiInventoryItems.filter { !excludedItemIds.contains($0.id) }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    /// 筛选后的系统物品定义（仅用于请求模式）
    private var filteredDefinitions: [DBItemDefinition] {
        guard isRequestMode else { return [] }

        var result = Array(inventoryManager.itemDefinitions.values)

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        // 按名称排序
        return result.sorted { $0.name < $1.name }
    }

    /// 已选物品总数
    private var totalSelectedCount: Int {
        if isRequestMode {
            return selectedDefinitions.reduce(0) { $0 + $1.quantity }
        } else {
            return selectedItems.reduce(0) { $0 + $1.quantity }
        }
    }

    /// 已选种类数
    private var selectedKindCount: Int {
        if isRequestMode {
            return selectedDefinitions.count
        } else {
            return selectedItems.count
        }
    }

    /// 是否有选中项
    private var hasSelection: Bool {
        if isRequestMode {
            return !selectedDefinitions.isEmpty
        } else {
            return !selectedItems.isEmpty
        }
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // 分类筛选
                categoryFilter
                    .padding(.top, 12)

                // 物品列表
                itemList
                    .padding(.top, 12)

                // 底部确认栏
                if hasSelection {
                    confirmBar
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(isRequestMode
                ? languageManager.localizedString("trade_select_request")
                : languageManager.localizedString("trade_select_offer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .task {
                // 确保库存数据已加载
                if inventoryManager.inventoryItems.isEmpty && inventoryManager.aiInventoryItems.isEmpty {
                    await inventoryManager.loadInventory()
                }
                // 确保物品定义已加载（用于请求模式）
                if inventoryManager.itemDefinitions.isEmpty {
                    await inventoryManager.loadItemDefinitions()
                }
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)
                .font(.system(size: 16))

            TextField(languageManager.localizedString("搜索物品..."), text: $searchText)
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

    // MARK: - 物品列表

    private var itemList: some View {
        ScrollView {
            if isRequestMode {
                // 请求模式：显示所有系统物品定义
                if filteredDefinitions.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 10) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.primary)

                            Text(languageManager.localizedString("trade_all_items"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        ForEach(filteredDefinitions) { definition in
                            PickerItemCard(
                                name: definition.name,
                                icon: definition.icon,
                                category: definition.category,
                                rarity: definition.rarity,
                                maxQuantity: 999,  // 请求模式下不限数量
                                isAI: false,
                                isSelected: isDefinitionSelected(id: definition.id),
                                selectedQuantity: getDefinitionSelectedQuantity(id: definition.id),
                                onSelect: { quantity in
                                    toggleDefinition(definition: definition, quantity: quantity)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            } else {
                // 出售模式：显示用户背包物品
                if filteredItems.isEmpty && filteredAIItems.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 10) {
                        // AI 物品
                        if !filteredAIItems.isEmpty {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12))
                                    .foregroundColor(.purple)

                                Text(languageManager.localizedString("AI 生成物品"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.purple)

                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            ForEach(filteredAIItems) { item in
                                PickerItemCard(
                                    name: item.name,
                                    icon: item.icon,
                                    category: item.category,
                                    rarity: item.rarity,
                                    maxQuantity: item.quantity,
                                    isAI: true,
                                    isSelected: isItemSelected(id: item.id),
                                    selectedQuantity: getSelectedQuantity(id: item.id),
                                    onSelect: { quantity in
                                        toggleItem(id: item.id, item: item, quantity: quantity, maxQuantity: item.quantity, isAI: true)
                                    }
                                )
                            }
                        }

                        // 普通物品
                        if !filteredItems.isEmpty {
                            if !filteredAIItems.isEmpty {
                                HStack {
                                    Image(systemName: "cube.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(ApocalypseTheme.textMuted)

                                    Text(languageManager.localizedString("普通物品"))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(ApocalypseTheme.textSecondary)

                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 12)
                            }

                            ForEach(filteredItems) { item in
                                if let definition = inventoryManager.getDefinition(for: item.itemId) {
                                    PickerItemCard(
                                        name: definition.name,
                                        icon: definition.icon,
                                        category: definition.category,
                                        rarity: definition.rarity,
                                        maxQuantity: item.quantity,
                                        isAI: false,
                                        isSelected: isItemSelected(id: item.id),
                                        selectedQuantity: getSelectedQuantity(id: item.id),
                                        onSelect: { quantity in
                                            toggleItem(id: item.id, item: item, quantity: quantity, maxQuantity: item.quantity, isAI: false)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(languageManager.localizedString("trade_no_items"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - 底部确认栏

    private var confirmBar: some View {
        HStack(spacing: 12) {
            // 已选数量
            VStack(alignment: .leading, spacing: 2) {
                Text(languageManager.localizedString("trade_selected"))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("\(selectedKindCount) \(languageManager.localizedString("trade_items_count")) (\(totalSelectedCount))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            Spacer()

            // 确认按钮
            Button {
                confirmSelection()
            } label: {
                Text(languageManager.localizedString("trade_btn_confirm"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ApocalypseTheme.primary)
                    )
            }
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(ApocalypseTheme.cardBackground)
                .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
        )
    }

    // MARK: - 辅助方法

    private func isItemSelected(id: UUID) -> Bool {
        selectedItems.contains { $0.id == id }
    }

    private func getSelectedQuantity(id: UUID) -> Int {
        selectedItems.first { $0.id == id }?.quantity ?? 0
    }

    private func toggleItem(id: UUID, item: Any, quantity: Int, maxQuantity: Int, isAI: Bool) {
        if let index = selectedItems.firstIndex(where: { $0.id == id }) {
            if quantity == 0 {
                selectedItems.remove(at: index)
            } else {
                selectedItems[index].quantity = quantity
            }
        } else if quantity > 0 {
            selectedItems.append(SelectedItem(id: id, item: item, quantity: quantity, maxQuantity: maxQuantity, isAI: isAI))
        }
    }

    // MARK: - 物品定义选择（请求模式）

    @State private var selectedDefinitions: [SelectedDefinition] = []

    struct SelectedDefinition: Identifiable {
        let id: String  // definition.id
        let definition: DBItemDefinition
        var quantity: Int
    }

    private func isDefinitionSelected(id: String) -> Bool {
        selectedDefinitions.contains { $0.id == id }
    }

    private func getDefinitionSelectedQuantity(id: String) -> Int {
        selectedDefinitions.first { $0.id == id }?.quantity ?? 0
    }

    private func toggleDefinition(definition: DBItemDefinition, quantity: Int) {
        if let index = selectedDefinitions.firstIndex(where: { $0.id == definition.id }) {
            if quantity == 0 {
                selectedDefinitions.remove(at: index)
            } else {
                selectedDefinitions[index].quantity = quantity
            }
        } else if quantity > 0 {
            selectedDefinitions.append(SelectedDefinition(id: definition.id, definition: definition, quantity: quantity))
        }
    }

    private func confirmSelection() {
        var tradeItems: [TradeItem] = []

        if isRequestMode {
            // 请求模式：从物品定义创建 TradeItem
            tradeItems = selectedDefinitions.map { selected in
                TradeItem(
                    itemId: UUID(),  // 生成新的 UUID，因为这是想要的物品
                    itemType: "normal",
                    itemName: selected.definition.name,
                    quantity: selected.quantity,
                    category: selected.definition.category,
                    rarity: selected.definition.rarity,
                    icon: selected.definition.icon
                )
            }
        } else {
            // 出售模式：从背包物品创建 TradeItem
            tradeItems = selectedItems.compactMap { selected in
                if selected.isAI, let item = selected.item as? DBAIInventoryItem {
                    return TradeManager.shared.createTradeItem(from: item, quantity: selected.quantity)
                } else if let item = selected.item as? DBInventoryItem {
                    let definition = inventoryManager.getDefinition(for: item.itemId)
                    return TradeManager.shared.createTradeItem(from: item, quantity: selected.quantity, definition: definition)
                }
                return nil
            }
        }

        onSelect(tradeItems)
        dismiss()
    }
}

// MARK: - 选择器物品卡片

struct PickerItemCard: View {
    let name: String
    let icon: String
    let category: String
    let rarity: String?
    let maxQuantity: Int
    let isAI: Bool
    let isSelected: Bool
    let selectedQuantity: Int
    let onSelect: (Int) -> Void

    @State private var quantity: Int = 0

    /// 分类颜色
    private var categoryColor: Color {
        switch category {
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

    /// 稀有度颜色
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

    /// 稀有度显示名称
    private var rarityDisplayName: String {
        switch rarity {
        case "common": return "普通"
        case "uncommon": return "少见"
        case "rare": return "稀有"
        case "epic": return "史诗"
        case "legendary": return "传说"
        default: return rarity ?? ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(categoryColor)

                if isAI {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                        .foregroundColor(.purple)
                        .offset(x: 14, y: -14)
                }
            }

            // 物品信息
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("x\(maxQuantity)")
                        .font(.system(size: 12))
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    if let rarity = rarity, !rarity.isEmpty {
                        Text(rarityDisplayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(rarityColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(rarityColor.opacity(0.15))
                            )
                    }
                }
            }

            Spacer()

            // 数量选择
            if isSelected {
                HStack(spacing: 8) {
                    Button {
                        let newQuantity = max(0, quantity - 1)
                        quantity = newQuantity
                        onSelect(newQuantity)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    Text("\(quantity)")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(minWidth: 30)

                    Button {
                        let newQuantity = min(maxQuantity, quantity + 1)
                        quantity = newQuantity
                        onSelect(newQuantity)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(ApocalypseTheme.primary)
                    }
                }
            } else {
                Button {
                    quantity = 1
                    onSelect(1)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? ApocalypseTheme.primary : Color.clear, lineWidth: 2)
                )
        )
        .onAppear {
            quantity = selectedQuantity
        }
        .onChange(of: selectedQuantity) { _, newValue in
            quantity = newValue
        }
    }
}

// MARK: - 预览

#Preview {
    ItemPickerView(
        isRequestMode: false,
        excludedItemIds: [],
        onSelect: { items in
            print("Selected: \(items)")
        }
    )
    .environmentObject(LanguageManager.shared)
}
