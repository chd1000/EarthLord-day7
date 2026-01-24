//
//  CategoryButton.swift
//  EarthLord day7
//
//  建筑分类按钮组件
//  用于建筑浏览器中的分类筛选
//

import SwiftUI

/// 建筑分类按钮
struct CategoryButton: View {

    // MARK: - 参数

    /// 分类（nil 表示"全部"）
    let category: BuildingCategory?

    /// 是否选中
    let isSelected: Bool

    /// 点击回调
    let action: () -> Void

    // MARK: - 视图

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 图标
                Image(systemName: iconName)
                    .font(.caption)

                // 文字
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.orange : Color(.secondarySystemGroupedBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 计算属性

    /// 图标名称
    private var iconName: String {
        guard let category = category else {
            return "square.grid.2x2"  // 全部
        }
        return category.icon
    }

    /// 显示名称
    private var displayName: String {
        guard let category = category else {
            return String(localized: "building_category_all")
        }
        return category.displayName
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 10) {
            CategoryButton(category: nil, isSelected: true) { }
            CategoryButton(category: .survival, isSelected: false) { }
            CategoryButton(category: .storage, isSelected: false) { }
        }
        HStack(spacing: 10) {
            CategoryButton(category: .production, isSelected: false) { }
            CategoryButton(category: .energy, isSelected: false) { }
        }
    }
    .padding()
}
