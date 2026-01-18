//
//  BackpackView.swift
//  EarthLord day7
//
//  背包管理页面
//  显示背包容量、物品列表、搜索筛选功能
//

import SwiftUI

struct BackpackView: View {

    // MARK: - 状态

    /// 背包管理器
    @StateObject private var inventoryManager = InventoryManager.shared

    /// 搜索文字
    @State private var searchText: String = ""

    /// 当前选中的分类（nil 表示全部）
    @State private var selectedCategory: String? = nil

    /// 动画显示的容量值
    @State private var animatedCapacity: Double = 0

    /// 物品列表显示状态（用于切换动画）
    @State private var showItems: Bool = true

    /// 背包容量上限
    private let maxCapacity: Double = 100.0

    // MARK: - 计算属性

    /// 当前背包使用量（基于重量）
    private var currentCapacity: Double {
        inventoryManager.totalWeight
    }

    /// 容量使用百分比
    private var capacityPercentage: Double {
        currentCapacity / maxCapacity
    }

    /// 进度条颜色
    private var capacityColor: Color {
        if capacityPercentage > 0.9 {
            return ApocalypseTheme.danger
        } else if capacityPercentage > 0.7 {
            return ApocalypseTheme.warning
        } else {
            return ApocalypseTheme.success
        }
    }

    /// 筛选后的普通物品列表
    private var filteredItems: [DBInventoryItem] {
        var result = inventoryManager.inventoryItems

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { item in
                inventoryManager.getDefinition(for: item.itemId)?.category == category
            }
        }

        // 按搜索文字筛选
        if !searchText.isEmpty {
            result = result.filter { item in
                inventoryManager.getDefinition(for: item.itemId)?.name
                    .localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return result
    }

    /// 筛选后的 AI 物品列表
    private var filteredAIItems: [DBAIInventoryItem] {
        var result = inventoryManager.aiInventoryItems

        // 按分类筛选
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // 按搜索文字筛选
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    /// 是否有任何物品
    private var hasAnyItems: Bool {
        !filteredAIItems.isEmpty || !filteredItems.isEmpty
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            if inventoryManager.isLoading && inventoryManager.inventoryItems.isEmpty {
                // 加载中
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("加载背包...")
                        .font(.system(size: 14))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            } else {
                VStack(spacing: 0) {
                    // 容量状态卡
                    capacityCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // 搜索框
                    searchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // 分类筛选
                    categoryFilter
                        .padding(.top, 12)

                    // 物品列表
                    itemListView
                        .padding(.top, 12)
                }
            }
        }
        .navigationTitle("背包")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 加载背包数据
            Task {
                await inventoryManager.loadInventory()
                // 容量进度条动画
                withAnimation(.easeOut(duration: 0.8)) {
                    animatedCapacity = currentCapacity
                }
            }
        }
        .onChange(of: inventoryManager.totalWeight) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedCapacity = newValue
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时的过渡动画
            withAnimation(.easeOut(duration: 0.15)) {
                showItems = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeIn(duration: 0.2)) {
                    showItems = true
                }
            }
        }
        .refreshable {
            await inventoryManager.loadInventory()
        }
    }

    // MARK: - 容量状态卡

    /// 背包容量状态卡
    private var capacityCard: some View {
        VStack(spacing: 12) {
            // 标题行
            HStack {
                Image(systemName: "bag.fill")
                    .foregroundColor(ApocalypseTheme.primary)

                Text("背包容量")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 容量数值（带动画）
                Text("\(String(format: "%.1f", animatedCapacity)) / \(Int(maxCapacity)) kg")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(capacityColor)
                    .contentTransition(.numericText())
            }

            // 进度条（带动画）
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景条
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ApocalypseTheme.textMuted.opacity(0.3))
                        .frame(height: 8)

                    // 进度条
                    RoundedRectangle(cornerRadius: 4)
                        .fill(capacityColor)
                        .frame(width: geometry.size.width * min(animatedCapacity / maxCapacity, 1.0), height: 8)
                        .animation(.easeOut(duration: 0.8), value: animatedCapacity)
                }
            }
            .frame(height: 8)

            // 警告文字（超过90%时显示）
            if capacityPercentage > 0.9 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))

                    Text("背包快满了！")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(ApocalypseTheme.danger)
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
        .animation(.easeInOut(duration: 0.3), value: capacityPercentage > 0.9)
    }

    // MARK: - 搜索框

    /// 搜索框
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textMuted)
                .font(.system(size: 16))

            TextField("搜索物品...", text: $searchText)
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

    /// 分类筛选按钮
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                CategoryChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 食物
                CategoryChip(
                    title: "食物",
                    icon: "fork.knife",
                    color: .orange,
                    isSelected: selectedCategory == "food"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "food"
                    }
                }

                // 材料
                CategoryChip(
                    title: "材料",
                    icon: "cube.fill",
                    color: .brown,
                    isSelected: selectedCategory == "material"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "material"
                    }
                }

                // 工具
                CategoryChip(
                    title: "工具",
                    icon: "wrench.and.screwdriver.fill",
                    color: .gray,
                    isSelected: selectedCategory == "tool"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "tool"
                    }
                }

                // 医疗
                CategoryChip(
                    title: "医疗",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == "medical"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = "medical"
                    }
                }

                // 装备
                CategoryChip(
                    title: "装备",
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

    /// 物品列表视图
    private var itemListView: some View {
        ScrollView {
            if !hasAnyItems {
                // 空状态
                emptyStateView
            } else {
                LazyVStack(spacing: 10) {
                    // AI 物品区域（置顶显示）
                    if !filteredAIItems.isEmpty {
                        // AI 物品分组标题
                        HStack {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundColor(.purple)

                            Text("AI 生成物品")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.purple)

                            Text("(\(filteredAIItems.count))")
                                .font(.system(size: 12))
                                .foregroundColor(ApocalypseTheme.textMuted)

                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)

                        ForEach(filteredAIItems) { item in
                            AIBackpackItemCard(
                                item: item,
                                onUse: {
                                    Task {
                                        await inventoryManager.useAIItem(itemId: item.id)
                                    }
                                }
                            )
                        }
                    }

                    // 普通物品区域
                    if !filteredItems.isEmpty {
                        // 如果有 AI 物品，显示普通物品分组标题
                        if !filteredAIItems.isEmpty {
                            HStack {
                                Image(systemName: "cube.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textMuted)

                                Text("普通物品")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textSecondary)

                                Text("(\(filteredItems.count))")
                                    .font(.system(size: 12))
                                    .foregroundColor(ApocalypseTheme.textMuted)

                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 12)
                        }

                        ForEach(filteredItems) { item in
                            if let definition = inventoryManager.getDefinition(for: item.itemId) {
                                BackpackItemCard(
                                    item: item,
                                    definition: definition,
                                    onUse: {
                                        Task {
                                            await inventoryManager.useItem(itemId: item.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .opacity(showItems ? 1 : 0)
                .offset(y: showItems ? 0 : 10)
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if inventoryManager.inventoryItems.isEmpty && inventoryManager.aiInventoryItems.isEmpty {
                // 背包完全为空
                Image(systemName: "bag")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("背包空空如也")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("去探索收集物资吧")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                // 搜索或筛选后没有结果
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到相关物品")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("试试其他搜索词或分类")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }
}

// MARK: - 分类按钮组件

/// 分类筛选按钮
struct CategoryChip: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))

                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 物品卡片组件（新版）

/// 背包物品卡片
struct BackpackItemCard: View {
    let item: DBInventoryItem
    let definition: DBItemDefinition
    let onUse: () -> Void

    /// 分类颜色
    private var categoryColor: Color {
        switch definition.category {
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
        switch definition.rarity {
        case "common": return .gray
        case "uncommon": return .green
        case "rare": return .blue
        case "epic": return .purple
        case "legendary": return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 左边：圆形图标
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: definition.icon)
                    .font(.system(size: 20))
                    .foregroundColor(categoryColor)
            }

            // 中间：物品信息
            VStack(alignment: .leading, spacing: 6) {
                // 第一行：名称 + 数量
                HStack(spacing: 6) {
                    Text(definition.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("x\(item.quantity)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 第二行：重量 + 稀有度
                HStack(spacing: 8) {
                    // 重量
                    HStack(spacing: 3) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 10))
                        Text(String(format: "%.1fkg", (definition.weight ?? 0) * Double(item.quantity)))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(ApocalypseTheme.textMuted)

                    // 稀有度标签
                    Text(definition.rarityDisplayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(rarityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(rarityColor.opacity(0.15))
                        )
                }
            }

            Spacer()

            // 右边：操作按钮
            VStack(spacing: 8) {
                // 使用按钮
                Button {
                    onUse()
                } label: {
                    Text("使用")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(ApocalypseTheme.primary)
                        )
                }

                // 存储按钮
                Button {
                    // TODO: 实现存储逻辑
                } label: {
                    Text("存储")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .stroke(ApocalypseTheme.textMuted.opacity(0.5), lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

// MARK: - AI 物品卡片组件

/// AI 背包物品卡片
struct AIBackpackItemCard: View {
    let item: DBAIInventoryItem
    let onUse: () -> Void

    /// 展开状态（显示故事）
    @State private var isExpanded: Bool = false

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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // 左边：圆形图标（带 AI 标记）
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                        .foregroundColor(categoryColor)

                    // AI 标记
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                        .offset(x: 16, y: -16)
                }

                // 中间：物品信息
                VStack(alignment: .leading, spacing: 6) {
                    // 第一行：名称 + 数量
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ApocalypseTheme.textPrimary)

                        Text("x\(item.quantity)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    // 第二行：分类 + 稀有度
                    HStack(spacing: 8) {
                        // 分类
                        Text(item.categoryDisplayName)
                            .font(.system(size: 11))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        // 稀有度标签
                        Text(item.rarityDisplayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(rarityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(rarityColor.opacity(0.15))
                            )
                    }
                }

                Spacer()

                // 右边：操作按钮和展开指示器
                VStack(spacing: 8) {
                    // 使用按钮
                    Button {
                        onUse()
                    } label: {
                        Text("使用")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(ApocalypseTheme.primary)
                            )
                    }

                    // 展开/收起指示器（如果有故事）
                    if item.story != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                }
            }
            .padding(14)

            // 故事展开区域
            if isExpanded, let story = item.story {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.horizontal, 14)

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "quote.opening")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(story)
                            .font(.system(size: 12))
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // 来源信息
                    if let poiName = item.poiName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                            Text("来自: \(poiName)")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if item.story != nil {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        BackpackView()
    }
}
