//
//  BuildingPlacementView.swift
//  EarthLord day7
//
//  建造确认页
//  显示建筑预览、位置选择、资源消耗、确认建造
//

import SwiftUI
import CoreLocation

/// 建造确认页
struct BuildingPlacementView: View {

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 参数

    /// 建筑模板
    let template: BuildingTemplate

    /// 领地
    let territory: Territory

    /// 建造成功回调
    var onBuildSuccess: (() -> Void)?

    // MARK: - 状态

    /// 建筑管理器
    @StateObject private var buildingManager = BuildingManager.shared

    /// 选中的坐标
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    /// 是否显示位置选择器
    @State private var showLocationPicker = false

    /// 是否正在建造
    @State private var isBuilding = false

    /// 错误消息
    @State private var errorMessage: String?

    /// 是否显示错误弹窗
    @State private var showErrorAlert = false

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 建筑预览
                    buildingPreview

                    // 位置选择
                    locationSection

                    // 资源消耗
                    resourcesSection

                    // 建造时间
                    buildTimeSection

                    // 确认建造按钮
                    confirmButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "building_placement_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "取消")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                BuildingLocationPickerView(
                    territoryCoordinates: territory.coordinates,
                    existingBuildings: buildingManager.playerBuildings.filter { $0.territoryId == territory.id.uuidString },
                    buildingTemplates: Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) }),
                    selectedCoordinate: $selectedCoordinate
                )
            }
            .alert(String(localized: "building_error_title"), isPresented: $showErrorAlert) {
                Button(String(localized: "确定"), role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 子视图

    /// 建筑预览
    private var buildingPreview: some View {
        VStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(template.categoryEnum.color.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: template.icon)
                    .font(.system(size: 32))
                    .foregroundColor(template.categoryEnum.color)
            }

            // 名称
            Text(template.localizedName)
                .font(.title2)
                .fontWeight(.bold)

            // 分类 + 等级
            HStack(spacing: 6) {
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

    /// 位置选择区域
    private var locationSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.orange)
                Text(String(localized: "building_location"))
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Button {
                showLocationPicker = true
            } label: {
                HStack {
                    if let coord = selectedCoordinate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "building_location_selected"))
                                .font(.body)
                                .foregroundColor(.primary)

                            Text(String(format: "%.6f, %.6f", coord.latitude, coord.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(String(localized: "building_tap_to_select_location"))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 资源消耗区域
    private var resourcesSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "cube.box.fill")
                    .foregroundColor(.orange)
                Text(String(localized: "building_resource_cost"))
                    .font(.headline)
                Spacer()

                // 资源状态
                if canAfford {
                    Label(String(localized: "building_resources_sufficient"), systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label(String(localized: "building_resources_insufficient"), systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
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

    /// 建造时间区域
    private var buildTimeSection: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.blue)

            Text(String(localized: "building_build_time"))
                .foregroundColor(.secondary)

            Spacer()

            Text(formattedBuildTime)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 确认建造按钮
    private var confirmButton: some View {
        Button {
            Task {
                await startConstruction()
            }
        } label: {
            HStack {
                if isBuilding {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hammer.fill")
                }
                Text(isBuilding ? String(localized: "building_constructing") : String(localized: "building_confirm_construction"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canBuild ? Color.orange : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canBuild || isBuilding)
        .padding(.top, 10)
    }

    // MARK: - 计算属性

    /// 是否可以建造
    private var canBuild: Bool {
        return canAfford && selectedCoordinate != nil
    }

    /// 资源是否足够
    private var canAfford: Bool {
        for (resourceName, requiredAmount) in template.requiredResources {
            let owned = getOwnedAmount(for: resourceName)
            if owned < requiredAmount {
                return false
            }
        }
        return true
    }

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

    /// 开始建造
    private func startConstruction() async {
        guard let coordinate = selectedCoordinate else {
            errorMessage = String(localized: "building_error_no_location")
            showErrorAlert = true
            return
        }

        isBuilding = true

        do {
            // 使用 GCJ-02 坐标保存到数据库
            _ = try await buildingManager.startConstruction(
                templateId: template.templateId,
                territoryId: territory.id.uuidString,
                location: (lat: coordinate.latitude, lon: coordinate.longitude)
            )

            // 成功
            onBuildSuccess?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }

        isBuilding = false
    }
}

// MARK: - 预览

#Preview {
    BuildingPlacementView(
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
        ),
        territory: Territory(
            id: UUID(),
            userId: UUID(),
            name: "测试领地",
            path: "[[30.5, 121.4], [30.51, 121.41], [30.505, 121.42]]",
            polygon: nil,
            bboxMinLat: 30.5,
            bboxMaxLat: 30.51,
            bboxMinLon: 121.4,
            bboxMaxLon: 121.42,
            area: 1000,
            pointCount: 3,
            startedAt: nil,
            completedAt: nil,
            isActive: true,
            createdAt: Date()
        )
    )
}
