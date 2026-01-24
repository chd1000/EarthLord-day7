//
//  BuildingBrowserView.swift
//  EarthLord day7
//
//  建筑浏览器
//  显示分类Tab和建筑网格
//

import SwiftUI

/// 建筑浏览器
struct BuildingBrowserView: View {

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 参数

    /// 关闭回调
    var onDismiss: (() -> Void)?

    /// 开始建造回调
    var onStartConstruction: ((BuildingTemplate) -> Void)?

    // MARK: - 状态

    /// 建筑管理器
    @StateObject private var buildingManager = BuildingManager.shared

    /// 选中的分类（nil 表示全部）
    @State private var selectedCategory: BuildingCategory?

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选栏
                categoryBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                Divider()

                // 建筑网格
                buildingGrid
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "building_browser_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "关闭")) {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 确保模板已加载
                if buildingManager.buildingTemplates.isEmpty {
                    buildingManager.loadTemplates()
                }
            }
        }
    }

    // MARK: - 子视图

    /// 分类筛选栏
    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                CategoryButton(category: nil, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }

                // 各分类
                ForEach(BuildingCategory.allCases, id: \.self) { category in
                    CategoryButton(category: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    /// 建筑网格
    private var buildingGrid: some View {
        ScrollView {
            if filteredTemplates.isEmpty {
                // 空状态
                emptyStateView
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(filteredTemplates) { template in
                        BuildingCard(template: template) {
                            onStartConstruction?(template)
                        }
                    }
                }
                .padding()
            }
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text(String(localized: "building_empty_state"))
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 计算属性

    /// 筛选后的模板
    private var filteredTemplates: [BuildingTemplate] {
        guard let category = selectedCategory else {
            return buildingManager.buildingTemplates
        }
        return buildingManager.getTemplates(for: category)
    }
}

// MARK: - 预览

#Preview {
    BuildingBrowserView()
}
