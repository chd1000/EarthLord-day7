//
//  TerritoryBuildingRow.swift
//  EarthLord day7
//
//  领地建筑行组件
//  显示建筑图标、名称、等级、状态
//  建造中：进度环 + 倒计时
//  运行中：操作菜单（升级/拆除）
//

import SwiftUI

/// 领地建筑行
struct TerritoryBuildingRow: View {

    // MARK: - 参数

    /// 玩家建筑
    let building: PlayerBuilding

    /// 建筑模板
    let template: BuildingTemplate?

    /// 升级回调
    var onUpgrade: (() -> Void)?

    /// 拆除回调
    var onDemolish: (() -> Void)?

    // MARK: - 状态

    /// 定时器，用于更新倒计时
    @State private var timer: Timer?

    /// 当前时间（用于触发刷新）
    @State private var currentTime = Date()

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 14) {
            // 建筑图标
            buildingIcon

            // 建筑信息
            VStack(alignment: .leading, spacing: 4) {
                // 名称 + 等级
                HStack(spacing: 6) {
                    Text(building.buildingName)
                        .font(.headline)
                        .lineLimit(1)

                    if building.statusEnum == .active {
                        Text("Lv.\(building.level)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }

                // 状态
                statusView
            }

            Spacer()

            // 操作按钮
            if building.statusEnum == .active {
                actionMenu
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            startTimerIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - 子视图

    /// 建筑图标
    private var buildingIcon: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 10)
                .fill(categoryColor.opacity(0.15))
                .frame(width: 50, height: 50)

            // 图标或进度环
            if building.statusEnum == .constructing {
                // 建造中：进度环
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 36, height: 36)

                    Circle()
                        .trim(from: 0, to: building.buildProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: template?.icon ?? "building.2")
                        .font(.caption)
                        .foregroundColor(categoryColor)
                }
            } else {
                // 运行中：普通图标
                Image(systemName: template?.icon ?? "building.2")
                    .font(.title2)
                    .foregroundColor(categoryColor)
            }
        }
    }

    /// 状态视图
    @ViewBuilder
    private var statusView: some View {
        if building.statusEnum == .constructing {
            // 建造中状态 - 使用 currentTime 触发刷新
            let _ = currentTime // 强制依赖 currentTime 以触发视图刷新
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text(building.formattedRemainingTime)
                    .font(.caption)
                    .foregroundColor(.blue)

                Text("·")
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%%", building.buildProgress * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            // 运行中状态
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)

                Text(building.statusEnum.displayName)
                    .font(.caption)
                    .foregroundColor(.green)

                if let maxLevel = template?.maxLevel, building.level < maxLevel {
                    Text("·")
                        .foregroundColor(.secondary)

                    Text(String(localized: "building_can_upgrade"))
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    /// 操作菜单
    private var actionMenu: some View {
        Menu {
            // 升级按钮
            if let maxLevel = template?.maxLevel, building.level < maxLevel {
                Button {
                    onUpgrade?()
                } label: {
                    Label(String(localized: "building_action_upgrade"), systemImage: "arrow.up.circle")
                }
            }

            // 拆除按钮
            Button(role: .destructive) {
                onDemolish?()
            } label: {
                Label(String(localized: "building_action_demolish"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 计算属性

    /// 分类颜色
    private var categoryColor: Color {
        template?.categoryEnum.color ?? .orange
    }

    // MARK: - 定时器

    /// 如果正在建造，启动定时器
    private func startTimerIfNeeded() {
        guard building.statusEnum == .constructing else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    /// 停止定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 12) {
        // 建造中
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "test",
                templateId: "campfire",
                buildingName: "篝火",
                status: "constructing",
                level: 1,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: Date().addingTimeInterval(-30),
                buildCompletedAt: Date().addingTimeInterval(30),
                createdAt: Date(),
                updatedAt: Date()
            ),
            template: BuildingTemplate(
                id: "1",
                templateId: "campfire",
                name: "building_campfire",
                category: "survival",
                tier: 1,
                description: "building_campfire_desc",
                icon: "flame.fill",
                requiredResources: [:],
                buildTimeSeconds: 60,
                maxPerTerritory: 1,
                maxLevel: 3
            )
        )

        // 运行中
        TerritoryBuildingRow(
            building: PlayerBuilding(
                id: UUID(),
                userId: UUID(),
                territoryId: "test",
                templateId: "storage_box",
                buildingName: "储物箱",
                status: "active",
                level: 2,
                locationLat: nil,
                locationLon: nil,
                buildStartedAt: nil,
                buildCompletedAt: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            template: BuildingTemplate(
                id: "2",
                templateId: "storage_box",
                name: "building_storage_box",
                category: "storage",
                tier: 1,
                description: "building_storage_box_desc",
                icon: "archivebox.fill",
                requiredResources: [:],
                buildTimeSeconds: 120,
                maxPerTerritory: 3,
                maxLevel: 5
            )
        )
    }
    .padding()
}
