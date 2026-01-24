//
//  ResourceRow.swift
//  EarthLord day7
//
//  资源行组件
//  显示资源图标、名称、需要/拥有数量
//

import SwiftUI

/// 资源行
struct ResourceRow: View {

    // MARK: - 参数

    /// 资源名称（如 wood, stone, metal）
    let resourceName: String

    /// 需要的数量
    let requiredAmount: Int

    /// 拥有的数量
    let ownedAmount: Int

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 12) {
            // 资源图标
            Image(systemName: resourceIcon)
                .font(.title3)
                .foregroundColor(resourceColor)
                .frame(width: 24)

            // 资源名称
            Text(localizedResourceName)
                .font(.body)

            Spacer()

            // 数量显示
            HStack(spacing: 4) {
                Text("\(ownedAmount)")
                    .fontWeight(.medium)
                    .foregroundColor(isEnough ? .green : .red)

                Text("/")
                    .foregroundColor(.secondary)

                Text("\(requiredAmount)")
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .font(.body)

            // 状态图标
            Image(systemName: isEnough ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isEnough ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 计算属性

    /// 是否足够
    private var isEnough: Bool {
        ownedAmount >= requiredAmount
    }

    /// 资源图标
    private var resourceIcon: String {
        switch resourceName.lowercased() {
        case "wood":
            return "leaf.fill"
        case "stone":
            return "mountain.2.fill"
        case "metal":
            return "gearshape.fill"
        case "glass":
            return "square.fill"
        case "food":
            return "fork.knife"
        case "water":
            return "drop.fill"
        case "fuel":
            return "fuelpump.fill"
        default:
            return "cube.fill"
        }
    }

    /// 资源颜色
    private var resourceColor: Color {
        switch resourceName.lowercased() {
        case "wood":
            return .brown
        case "stone":
            return .gray
        case "metal":
            return .orange
        case "glass":
            return .cyan
        case "food":
            return .green
        case "water":
            return .blue
        case "fuel":
            return .yellow
        default:
            return .secondary
        }
    }

    /// 本地化资源名称
    private var localizedResourceName: String {
        switch resourceName.lowercased() {
        case "wood":
            return String(localized: "resource_wood")
        case "stone":
            return String(localized: "resource_stone")
        case "metal":
            return String(localized: "resource_metal")
        case "glass":
            return String(localized: "resource_glass")
        case "food":
            return String(localized: "resource_food")
        case "water":
            return String(localized: "resource_water")
        case "fuel":
            return String(localized: "resource_fuel")
        default:
            return resourceName
        }
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 0) {
        ResourceRow(resourceName: "wood", requiredAmount: 50, ownedAmount: 120)
        Divider().padding(.leading, 36)
        ResourceRow(resourceName: "stone", requiredAmount: 30, ownedAmount: 15)
        Divider().padding(.leading, 36)
        ResourceRow(resourceName: "metal", requiredAmount: 10, ownedAmount: 10)
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .padding()
}
