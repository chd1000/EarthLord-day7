//
//  BuildingCard.swift
//  EarthLord day7
//
//  建筑卡片组件
//  显示建筑图标、名称、分类和等级
//

import SwiftUI

/// 建筑卡片
struct BuildingCard: View {

    // MARK: - 参数

    /// 建筑模板
    let template: BuildingTemplate

    /// 点击回调
    let onTap: () -> Void

    // MARK: - 视图

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.categoryEnum.color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: template.icon)
                        .font(.title)
                        .foregroundColor(template.categoryEnum.color)
                }

                // 名称
                Text(template.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                // 分类 + 等级
                HStack(spacing: 4) {
                    Text(template.categoryEnum.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(template.tierDisplayText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(template.categoryEnum.color)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BuildingCategory 颜色扩展

extension BuildingCategory {

    /// 分类颜色
    var color: Color {
        switch self {
        case .survival:
            return .red
        case .storage:
            return .blue
        case .production:
            return .purple
        case .energy:
            return .yellow
        }
    }
}

// MARK: - 预览

#Preview {
    LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
    ], spacing: 12) {
        BuildingCard(
            template: BuildingTemplate(
                id: "1",
                templateId: "campfire",
                name: "building_campfire",
                category: "survival",
                tier: 1,
                description: "building_campfire_desc",
                icon: "flame.fill",
                requiredResources: ["wood": 10],
                buildTimeSeconds: 60,
                maxPerTerritory: 1,
                maxLevel: 3
            )
        ) { }

        BuildingCard(
            template: BuildingTemplate(
                id: "2",
                templateId: "storage_box",
                name: "building_storage_box",
                category: "storage",
                tier: 1,
                description: "building_storage_box_desc",
                icon: "archivebox.fill",
                requiredResources: ["wood": 20, "metal": 5],
                buildTimeSeconds: 120,
                maxPerTerritory: 3,
                maxLevel: 5
            )
        ) { }
    }
    .padding()
}
