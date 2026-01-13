//
//  POIListView.swift
//  EarthLord day7
//
//  附近兴趣点列表页面
//  显示 GPS 状态、搜索按钮、分类筛选、POI 列表
//

import SwiftUI

struct POIListView: View {

    // MARK: - 状态

    /// POI 列表（从 MockData 加载）
    @State private var poiList: [POI] = MockExplorationData.mockPOIs

    /// 当前选中的筛选分类（nil 表示全部）
    @State private var selectedCategory: POIType? = nil

    /// 是否正在搜索
    @State private var isSearching: Bool = false

    /// 搜索按钮缩放状态
    @State private var searchButtonScale: CGFloat = 1.0

    /// POI 列表项显示状态（用于依次淡入动画）
    @State private var visibleItems: Set<UUID> = []

    /// 假 GPS 坐标
    private let mockLatitude: Double = 22.54
    private let mockLongitude: Double = 114.06

    // MARK: - 计算属性

    /// 筛选后的 POI 列表
    private var filteredPOIs: [POI] {
        if let category = selectedCategory {
            return poiList.filter { $0.type == category }
        }
        return poiList
    }

    /// 已发现的 POI 数量
    private var discoveredCount: Int {
        poiList.filter { $0.status != .undiscovered }.count
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态栏
                statusBar

                // 搜索按钮
                searchButton
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                // 筛选工具栏
                filterToolbar
                    .padding(.top, 16)

                // POI 列表
                poiListView
                    .padding(.top, 12)
            }
        }
        .navigationTitle("附近地点")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态栏

    /// 顶部状态栏（GPS 坐标 + 发现数量）
    private var statusBar: some View {
        HStack {
            // GPS 坐标
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .foregroundColor(ApocalypseTheme.success)
                    .font(.system(size: 12))

                Text(String(format: "%.2f, %.2f", mockLatitude, mockLongitude))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 发现数量
            HStack(spacing: 6) {
                Image(systemName: "binoculars.fill")
                    .foregroundColor(ApocalypseTheme.primary)
                    .font(.system(size: 12))

                Text("附近发现 \(discoveredCount) 个地点")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.cardBackground)
    }

    // MARK: - 搜索按钮

    /// 搜索附近 POI 按钮
    private var searchButton: some View {
        Button {
            // 点击缩放动画
            withAnimation(.easeInOut(duration: 0.1)) {
                searchButtonScale = 0.95
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    searchButtonScale = 1.0
                }
            }
            performSearch()
        } label: {
            HStack(spacing: 12) {
                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)

                    Text("搜索中...")
                        .font(.system(size: 16, weight: .semibold))
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18))

                    Text("搜索附近POI")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSearching ? ApocalypseTheme.textMuted : ApocalypseTheme.primary)
            )
        }
        .scaleEffect(searchButtonScale)
        .disabled(isSearching)
    }

    // MARK: - 筛选工具栏

    /// 分类筛选工具栏
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                FilterChip(
                    title: "全部",
                    icon: "square.grid.2x2.fill",
                    color: ApocalypseTheme.primary,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = nil
                    }
                }

                // 医院
                FilterChip(
                    title: "医院",
                    icon: "cross.case.fill",
                    color: .red,
                    isSelected: selectedCategory == .hospital
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = .hospital
                    }
                }

                // 超市
                FilterChip(
                    title: "超市",
                    icon: "cart.fill",
                    color: .green,
                    isSelected: selectedCategory == .supermarket
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = .supermarket
                    }
                }

                // 工厂
                FilterChip(
                    title: "工厂",
                    icon: "building.2.fill",
                    color: .gray,
                    isSelected: selectedCategory == .factory
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = .factory
                    }
                }

                // 药店
                FilterChip(
                    title: "药店",
                    icon: "pills.fill",
                    color: .purple,
                    isSelected: selectedCategory == .pharmacy
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = .pharmacy
                    }
                }

                // 加油站
                FilterChip(
                    title: "加油站",
                    icon: "fuelpump.fill",
                    color: .orange,
                    isSelected: selectedCategory == .gasStation
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = .gasStation
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - POI 列表

    /// POI 列表视图
    private var poiListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                if filteredPOIs.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredPOIs.enumerated()), id: \.element.id) { index, poi in
                            NavigationLink(destination: POIDetailView(poi: poi)) {
                                POICard(poi: poi)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .opacity(visibleItems.contains(poi.id) ? 1 : 0)
                            .offset(y: visibleItems.contains(poi.id) ? 0 : 20)
                            .onAppear {
                                // 依次淡入动画，每个间隔 0.1 秒
                                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        _ = visibleItems.insert(poi.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .onChange(of: selectedCategory) { _, _ in
            // 切换分类时重置动画状态，然后重新触发动画
            visibleItems.removeAll()
            // 延迟后重新添加所有项目到可见集合
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                for (index, poi) in filteredPOIs.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            _ = visibleItems.insert(poi.id)
                        }
                    }
                }
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // 根据是否有筛选条件显示不同的空状态
            if poiList.isEmpty {
                // 完全没有 POI 数据
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("附近暂无兴趣点")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("点击搜索按钮发现周围的废墟")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else if selectedCategory != nil {
                // 筛选后没有结果
                Image(systemName: "mappin.slash")
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.textMuted)

                Text("没有找到该类型的地点")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Text("试试切换其他分类")
                    .font(.system(size: 14))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - 方法

    /// 执行搜索（模拟网络请求）
    private func performSearch() {
        isSearching = true

        // 1.5 秒后恢复（模拟网络请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSearching = false
            // 这里可以刷新 POI 数据
            print("搜索完成，发现 \(poiList.count) 个地点")
        }
    }

}

// MARK: - 筛选按钮组件

/// 筛选标签按钮
struct FilterChip: View {
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

// MARK: - POI 卡片组件

/// POI 卡片
struct POICard: View {
    let poi: POI

    /// 根据 POI 类型返回颜色
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

    /// 状态标签颜色
    private var statusColor: Color {
        switch poi.status {
        case .undiscovered: return ApocalypseTheme.textMuted
        case .discovered: return ApocalypseTheme.success
        case .looted: return ApocalypseTheme.danger
        }
    }

    /// 状态图标
    private var statusIcon: String {
        switch poi.status {
        case .undiscovered: return "questionmark.circle"
        case .discovered: return "checkmark.circle.fill"
        case .looted: return "xmark.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // 类型图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: poi.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(typeColor)
            }

            // POI 信息
            VStack(alignment: .leading, spacing: 6) {
                // 名称
                Text(poi.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
                    .lineLimit(1)

                // 类型 + 状态
                HStack(spacing: 12) {
                    // 类型标签
                    Text(poi.typeDisplayName)
                        .font(.system(size: 12))
                        .foregroundColor(typeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(typeColor.opacity(0.15))
                        )

                    // 发现状态
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 11))
                        Text(poi.statusDisplayName)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(statusColor)
                }
            }

            Spacer()

            // 物资状态 + 箭头
            VStack(alignment: .trailing, spacing: 6) {
                // 物资状态
                if poi.status == .discovered {
                    HStack(spacing: 4) {
                        Image(systemName: poi.hasLoot ? "cube.box.fill" : "cube.box")
                            .font(.system(size: 12))
                        Text(poi.hasLoot ? "有物资" : "无物资")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(poi.hasLoot ? ApocalypseTheme.warning : ApocalypseTheme.textMuted)
                }

                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }
}

// MARK: - 预览

#Preview {
    NavigationStack {
        POIListView()
    }
}
