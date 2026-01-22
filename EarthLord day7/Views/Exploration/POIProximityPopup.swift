//
//  POIProximityPopup.swift
//  EarthLord day7
//
//  POI接近弹窗
//  当玩家进入POI 50米范围内时显示搜刮提示
//

import SwiftUI

/// POI接近弹窗
struct POIProximityPopup: View {

    // MARK: - 环境
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - 属性

    /// 当前POI
    let poi: POI

    /// 是否正在搜刮
    let isScavenging: Bool

    /// 搜刮动作
    let onScavenge: () -> Void

    /// 关闭动作
    let onDismiss: () -> Void

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            VStack(spacing: 16) {
                // 头部：图标和名称
                HStack(spacing: 12) {
                    // POI类型图标
                    ZStack {
                        Circle()
                            .fill(poiColor.opacity(0.2))
                            .frame(width: 50, height: 50)

                        Image(systemName: poiIcon)
                            .font(.system(size: 24))
                            .foregroundColor(poiColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        // POI名称
                        Text(poi.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        // 类型和距离
                        HStack(spacing: 8) {
                            Text(poi.type.localizedName(languageManager))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)

                            if let distance = poi.distanceFromUser {
                                Text("\(Int(distance))" + languageManager.localizedString("米"))
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    Spacer()

                    // 关闭按钮
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }

                // 危险等级和物资状态
                HStack(spacing: 16) {
                    // 危险等级
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(dangerColor)
                        Text(languageManager.localizedString("危险等级"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(poi.dangerLevel)/5")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(dangerColor)
                    }

                    Divider()
                        .frame(height: 16)

                    // 物资状态
                    HStack(spacing: 4) {
                        Image(systemName: poi.hasLoot ? "archivebox.fill" : "archivebox")
                            .foregroundColor(poi.hasLoot ? .green : .gray)
                        Text(poi.hasLoot ? languageManager.localizedString("有物资") : languageManager.localizedString("已搜刮"))
                            .font(.caption)
                            .foregroundColor(poi.hasLoot ? .green : .gray)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)

                // 描述文字
                if !poi.description.isEmpty {
                    Text(poi.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                // 搜刮按钮
                Button(action: onScavenge) {
                    HStack {
                        if isScavenging {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text(languageManager.localizedString("搜刮中..."))
                        } else {
                            Image(systemName: "hand.point.up.left.fill")
                            Text(languageManager.localizedString("开始搜刮"))
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        poi.canScavenge && !isScavenging
                            ? LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                }
                .disabled(!poi.canScavenge || isScavenging)
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }

    // MARK: - 计算属性

    /// POI颜色
    private var poiColor: Color {
        switch poi.type {
        case .hospital: return .red
        case .pharmacy: return .purple
        case .supermarket: return .green
        case .gasStation: return .orange
        case .police: return .blue
        case .warehouse: return .brown
        case .factory: return .gray
        case .house: return .teal
        case .military: return .green
        }
    }

    /// POI图标
    private var poiIcon: String {
        switch poi.type {
        case .hospital: return "cross.case.fill"
        case .pharmacy: return "pills.fill"
        case .supermarket: return "cart.fill"
        case .gasStation: return "fuelpump.fill"
        case .police: return "shield.fill"
        case .warehouse: return "shippingbox.fill"
        case .factory: return "building.2.fill"
        case .house: return "house.fill"
        case .military: return "airplane"
        }
    }

    /// 危险等级颜色
    private var dangerColor: Color {
        switch poi.dangerLevel {
        case 1...2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

// MARK: - 圆角扩展

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - 预览

#Preview {
    VStack {
        Spacer()
        POIProximityPopup(
            poi: POI(
                id: UUID(),
                name: "废弃的中心医院",
                type: .hospital,
                coordinate: POI.Coordinate(latitude: 31.2, longitude: 121.5),
                status: .discovered,
                hasLoot: true,
                dangerLevel: 4,
                description: "这座曾经救死扶伤的医院如今已成废墟，但可能还残留着珍贵的医疗物资。警惕，这里可能有其他幸存者或更危险的东西。",
                distanceFromUser: 35
            ),
            isScavenging: false,
            onScavenge: {},
            onDismiss: {}
        )
    }
    .background(Color.gray.opacity(0.3))
}
