//
//  TerritoryDetailView.swift
//  EarthLord day7
//
//  领地详情页面
//  全屏地图布局 + 建筑列表 + 操作菜单
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 参数

    let territory: Territory
    var onDelete: (() -> Void)?

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    // MARK: - 状态

    @StateObject private var territoryManager = TerritoryManager.shared
    @StateObject private var buildingManager = BuildingManager.shared

    /// 是否显示删除确认弹窗
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    /// 是否显示信息面板
    @State private var showInfoPanel = true

    /// 是否显示建筑浏览器
    @State private var showBuildingBrowser = false

    /// 选中的建筑模板（用于建造）
    @State private var selectedTemplateForConstruction: BuildingTemplate?

    /// 是否显示重命名对话框
    @State private var showRenameAlert = false

    /// 新名称
    @State private var newName: String = ""

    /// 是否显示拆除确认
    @State private var showDemolishAlert = false

    /// 待拆除的建筑
    @State private var buildingToDemolish: PlayerBuilding?

    /// 本地领地数据（用于更新名称）
    @State private var localTerritory: Territory

    // MARK: - 初始化

    init(territory: Territory, onDelete: (() -> Void)? = nil) {
        self.territory = territory
        self.onDelete = onDelete
        self._localTerritory = State(initialValue: territory)
        self._newName = State(initialValue: territory.name ?? "")
    }

    // MARK: - 视图

    var body: some View {
        ZStack {
            // 1. 全屏地图（底层）
            TerritoryMapView(
                territory: localTerritory,
                buildings: territoryBuildings,
                buildingTemplates: buildingTemplateDict
            )
            .ignoresSafeArea()

            // 2. 悬浮工具栏（顶部）
            VStack(spacing: 0) {
                TerritoryToolbarView(
                    territoryName: localTerritory.name ?? languageManager.localizedString("未命名领地"),
                    onClose: { dismiss() },
                    onBuild: { showBuildingBrowser = true },
                    onToggleInfo: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showInfoPanel.toggle()
                        }
                    },
                    isInfoPanelVisible: showInfoPanel
                )

                Spacer()
            }

            // 3. 可折叠信息面板（底部）
            VStack(spacing: 0) {
                Spacer()

                if showInfoPanel {
                    VStack(spacing: 0) {
                        infoPanelView

                        // 底部安全区域填充
                        Color(.systemBackground)
                            .frame(height: 34) // Home indicator 区域高度
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showBuildingBrowser) {
            BuildingBrowserView(
                onDismiss: {
                    showBuildingBrowser = false
                },
                onStartConstruction: { template in
                    showBuildingBrowser = false
                    // 延迟 0.3s 避免动画冲突
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTemplateForConstruction = template
                    }
                }
            )
        }
        .sheet(item: $selectedTemplateForConstruction) { template in
            BuildingPlacementView(
                template: template,
                territory: localTerritory,
                onBuildSuccess: {
                    // 刷新建筑列表
                    Task {
                        await buildingManager.fetchPlayerBuildings(territoryId: localTerritory.id.uuidString)
                    }
                }
            )
        }
        .alert(languageManager.localizedString("确认删除"), isPresented: $showDeleteAlert) {
            Button(languageManager.localizedString("取消"), role: .cancel) { }
            Button(languageManager.localizedString("删除"), role: .destructive) {
                Task {
                    await deleteTerritory()
                }
            }
        } message: {
            Text(languageManager.localizedString("确定要删除这块领地吗？此操作无法撤销。"))
        }
        .alert(languageManager.localizedString("重命名领地"), isPresented: $showRenameAlert) {
            TextField(languageManager.localizedString("领地名称"), text: $newName)
            Button(languageManager.localizedString("取消"), role: .cancel) { }
            Button(languageManager.localizedString("确定")) {
                Task {
                    await renameTerritory()
                }
            }
        }
        .alert(languageManager.localizedString("确认拆除"), isPresented: $showDemolishAlert) {
            Button(languageManager.localizedString("取消"), role: .cancel) {
                buildingToDemolish = nil
            }
            Button(languageManager.localizedString("拆除"), role: .destructive) {
                if let building = buildingToDemolish {
                    Task {
                        await demolishBuilding(building)
                    }
                }
            }
        } message: {
            if let building = buildingToDemolish {
                Text(String(format: languageManager.localizedString("确定要拆除 %@ 吗？"), building.buildingName))
            }
        }
        .task {
            // 加载建筑模板
            if buildingManager.buildingTemplates.isEmpty {
                buildingManager.loadTemplates()
            }
            // 加载该领地的建筑
            await buildingManager.fetchPlayerBuildings(territoryId: localTerritory.id.uuidString)
        }
    }

    // MARK: - 子视图

    /// 信息面板
    private var infoPanelView: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    // 领地名称 + 齿轮按钮
                    territoryHeader

                    // 领地信息卡片
                    infoCard

                    // 建筑列表
                    buildingListSection

                    // 删除按钮
                    deleteButton
                }
                .padding()
                .padding(.bottom, 20) // 底部额外间距
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        }
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .cornerRadius(20, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.2), radius: 10, y: -5)
    }

    /// 领地头部
    private var territoryHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localTerritory.name ?? languageManager.localizedString("未命名领地"))
                    .font(.title2)
                    .fontWeight(.bold)

                Text(localTerritory.formattedArea)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 重命名按钮
            Button {
                newName = localTerritory.name ?? ""
                showRenameAlert = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
    }

    /// 领地信息卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text(languageManager.localizedString("领地信息"))
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            VStack(spacing: 0) {
                InfoRow(label: languageManager.localizedString("面积"), value: localTerritory.formattedArea)
                Divider().padding(.leading)
                InfoRow(label: languageManager.localizedString("路径点数"), value: "\(localTerritory.pointCount) \(languageManager.localizedString("个"))")
                Divider().padding(.leading)
                InfoRow(label: languageManager.localizedString("创建时间"), value: localTerritory.formattedCreatedAt)
                Divider().padding(.leading)
                InfoRow(label: languageManager.localizedString("建筑数量"), value: "\(territoryBuildings.count)")
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 建筑列表区域
    private var buildingListSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.orange)
                Text(languageManager.localizedString("建筑列表"))
                    .font(.headline)
                Spacer()

                Text("\(territoryBuildings.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            if territoryBuildings.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text(languageManager.localizedString("暂无建筑"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showBuildingBrowser = true
                    } label: {
                        Label(languageManager.localizedString("开始建造"), systemImage: "hammer.fill")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(.vertical, 30)
            } else {
                // 建筑列表
                VStack(spacing: 8) {
                    ForEach(territoryBuildings) { building in
                        TerritoryBuildingRow(
                            building: building,
                            template: buildingTemplateDict[building.templateId],
                            onUpgrade: {
                                Task {
                                    await upgradeBuilding(building)
                                }
                            },
                            onDemolish: {
                                buildingToDemolish = building
                                showDemolishAlert = true
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 删除按钮
    private var deleteButton: some View {
        Button(action: {
            showDeleteAlert = true
        }) {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash")
                }
                Text(isDeleting ? languageManager.localizedString("删除中...") : languageManager.localizedString("删除领地"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
        .padding(.top, 10)
    }

    // MARK: - 计算属性

    /// 该领地的建筑
    private var territoryBuildings: [PlayerBuilding] {
        buildingManager.playerBuildings.filter { $0.territoryId == localTerritory.id.uuidString }
    }

    /// 建筑模板字典
    private var buildingTemplateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingManager.buildingTemplates.map { ($0.templateId, $0) })
    }

    // MARK: - 方法

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: localTerritory.id)

        isDeleting = false

        if success {
            onDelete?()
            dismiss()
        }
    }

    /// 重命名领地
    private func renameTerritory() async {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let success = await territoryManager.updateTerritoryName(
            territoryId: localTerritory.id,
            newName: trimmedName
        )

        if success {
            localTerritory.name = trimmedName
        }
    }

    /// 升级建筑
    private func upgradeBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.upgradeBuilding(buildingId: building.id)
        } catch {
            print("❌ 升级建筑失败: \(error)")
        }
    }

    /// 拆除建筑
    private func demolishBuilding(_ building: PlayerBuilding) async {
        do {
            try await buildingManager.demolishBuilding(buildingId: building.id)
        } catch {
            print("❌ 拆除建筑失败: \(error)")
        }
        buildingToDemolish = nil
    }
}

// MARK: - InfoRow 组件

/// 信息行组件
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - 预览

#Preview {
    TerritoryDetailView(
        territory: Territory(
            id: UUID(),
            userId: UUID(),
            name: "测试领地",
            path: "[[30.333, 121.324], [30.334, 121.325], [30.333, 121.326]]",
            polygon: nil,
            bboxMinLat: 30.333,
            bboxMaxLat: 30.334,
            bboxMinLon: 121.324,
            bboxMaxLon: 121.326,
            area: 1234.5,
            pointCount: 10,
            startedAt: nil,
            completedAt: nil,
            isActive: true,
            createdAt: Date()
        )
    )
    .environmentObject(LanguageManager.shared)
}
