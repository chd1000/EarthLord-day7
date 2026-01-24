//
//  BuildingDetailView.swift
//  EarthLord day7
//
//  建筑详情页
//  显示建筑详细信息
//

import SwiftUI

/// 建筑详情页
struct BuildingDetailView: View {

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 参数

    /// 建筑模板
    let template: BuildingTemplate

    /// 开始建造回调
    var onStartConstruction: (() -> Void)?

    // MARK: - 状态

    /// 建筑管理器
    @StateObject private var buildingManager = BuildingManager.shared

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 建筑图标和基本信息
                    headerView

                    // 建筑描述
                    descriptionCard

                    // 建筑属性
                    attributesCard

                    // 所需资源
                    resourcesCard

                    // 建造按钮
                    buildButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(template.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "关闭")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - 子视图

    /// 头部视图
    private var headerView: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.categoryEnum.color.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: template.icon)
                    .font(.system(size: 36))
                    .foregroundColor(template.categoryEnum.color)
            }

            // 分类和等级
            HStack(spacing: 8) {
                Label(template.categoryEnum.displayName, systemImage: template.categoryEnum.icon)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary)

                Text(template.tierDisplayText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(template.categoryEnum.color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 描述卡片
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.orange)
                Text(String(localized: "building_description"))
                    .font(.headline)
                Spacer()
            }

            Text(template.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 属性卡片
    private var attributesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text(String(localized: "building_attributes"))
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // 建造时间
            attributeRow(
                icon: "clock.fill",
                label: String(localized: "building_build_time"),
                value: formattedBuildTime
            )

            Divider().padding(.leading, 56)

            // 最大等级
            attributeRow(
                icon: "arrow.up.circle.fill",
                label: String(localized: "building_max_level"),
                value: "Lv.\(template.maxLevel)"
            )

            Divider().padding(.leading, 56)

            // 每领地上限
            attributeRow(
                icon: "square.stack.3d.up.fill",
                label: String(localized: "building_max_per_territory"),
                value: "\(template.maxPerTerritory)"
            )
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 属性行
    private func attributeRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .padding()
    }

    /// 资源卡片
    private var resourcesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(.orange)
                Text(String(localized: "building_required_resources"))
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ForEach(Array(template.requiredResources.keys.sorted()), id: \.self) { resourceName in
                let required = template.requiredResources[resourceName] ?? 0
                let owned = getOwnedAmount(for: resourceName)

                ResourceRow(
                    resourceName: resourceName,
                    requiredAmount: required,
                    ownedAmount: owned
                )
                .padding(.horizontal)

                if resourceName != template.requiredResources.keys.sorted().last {
                    Divider().padding(.leading, 56)
                }
            }

            if template.requiredResources.isEmpty {
                Text(String(localized: "building_no_resources_required"))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 建造按钮
    private var buildButton: some View {
        Button {
            onStartConstruction?()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "hammer.fill")
                Text(String(localized: "building_start_construction"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.top, 10)
    }

    // MARK: - 计算属性

    /// 格式化建造时间
    private var formattedBuildTime: String {
        let seconds = template.buildTimeSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    // MARK: - 方法

    /// 获取拥有的资源数量
    private func getOwnedAmount(for resourceName: String) -> Int {
        let inventory = InventoryManager.shared

        // 先检查普通物品
        if let item = inventory.inventoryItems.first(where: { $0.itemId == resourceName }) {
            return item.quantity
        }

        // 再检查 AI 物品
        let lowercaseName = resourceName.lowercased()
        if let aiItem = inventory.aiInventoryItems.first(where: {
            $0.name.lowercased() == lowercaseName ||
            $0.name.lowercased().contains(lowercaseName)
        }) {
            return aiItem.quantity
        }

        return 0
    }
}

// MARK: - 预览

#Preview {
    BuildingDetailView(
        template: BuildingTemplate(
            id: "1",
            templateId: "campfire",
            name: "building_campfire",
            category: "survival",
            tier: 1,
            description: "building_campfire_desc",
            icon: "flame.fill",
            requiredResources: ["wood": 10, "stone": 5],
            buildTimeSeconds: 300,
            maxPerTerritory: 1,
            maxLevel: 3
        )
    )
}
