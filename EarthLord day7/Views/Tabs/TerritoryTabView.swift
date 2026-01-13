//
//  TerritoryTabView.swift
//  EarthLord day7
//
//  领地管理 Tab 页面
//  显示我的领地列表、统计信息
//

import SwiftUI

struct TerritoryTabView: View {

    // MARK: - 状态

    @StateObject private var territoryManager = TerritoryManager.shared

    /// 我的领地列表
    @State private var myTerritories: [Territory] = []

    /// 选中的领地（用于显示详情 sheet）
    @State private var selectedTerritory: Territory?

    /// 是否正在加载
    @State private var isLoading: Bool = false

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景色
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if isLoading && myTerritories.isEmpty {
                    // 加载中
                    loadingView
                } else if myTerritories.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 领地列表
                    territoryListView
                }
            }
            .navigationTitle("我的领地")
            .refreshable {
                await loadMyTerritories()
            }
            .task {
                await loadMyTerritories()
            }
            .sheet(item: $selectedTerritory) { territory in
                TerritoryDetailView(
                    territory: territory,
                    onDelete: {
                        // 删除后刷新列表
                        Task {
                            await loadMyTerritories()
                        }
                    }
                )
            }
        }
    }

    // MARK: - 子视图

    /// 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("加载中...")
                .foregroundColor(.secondary)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("还没有领地")
                .font(.title2)
                .fontWeight(.medium)

            Text("去地图页面圈一块属于你的领地吧！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    /// 领地列表视图
    private var territoryListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 统计卡片
                statsCard

                // 领地列表
                ForEach(myTerritories) { territory in
                    TerritoryCard(territory: territory)
                        .onTapGesture {
                            selectedTerritory = territory
                        }
                }
            }
            .padding()
        }
    }

    /// 统计卡片
    private var statsCard: some View {
        HStack(spacing: 0) {
            // 领地数量
            StatItem(
                icon: "flag.fill",
                value: "\(myTerritories.count)",
                label: "领地数量"
            )

            Divider()
                .frame(height: 40)

            // 总面积
            StatItem(
                icon: "square.dashed",
                value: formattedTotalArea,
                label: "总面积"
            )
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 计算总面积
    private var formattedTotalArea: String {
        let total = myTerritories.reduce(0) { $0 + $1.area }
        if total >= 1_000_000 {
            return String(format: "%.2f km²", total / 1_000_000)
        } else {
            return String(format: "%.0f m²", total)
        }
    }

    // MARK: - 方法

    /// 加载我的领地
    private func loadMyTerritories() async {
        isLoading = true
        myTerritories = await territoryManager.loadMyTerritories()
        isLoading = false
        TerritoryLogger.shared.log("领地列表加载完成，共 \(myTerritories.count) 块", type: .info)
    }
}

// MARK: - 统计项组件

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 领地卡片组件

struct TerritoryCard: View {
    let territory: Territory

    var body: some View {
        HStack(spacing: 16) {
            // 领地图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: "flag.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }

            // 领地信息
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(territory.formattedArea, systemImage: "square.dashed")
                    Label("\(territory.pointCount) 点", systemImage: "mappin.circle")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - 预览

#Preview {
    TerritoryTabView()
}
