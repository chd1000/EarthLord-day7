//
//  TerritoryDetailView.swift
//  EarthLord day7
//
//  领地详情页面
//  显示领地地图预览、详细信息、删除功能
//

import SwiftUI
import MapKit

struct TerritoryDetailView: View {

    // MARK: - 参数

    let territory: Territory
    var onDelete: (() -> Void)?

    // MARK: - 环境

    @Environment(\.dismiss) private var dismiss

    // MARK: - 状态

    @StateObject private var territoryManager = TerritoryManager.shared

    /// 是否显示删除确认弹窗
    @State private var showDeleteAlert = false

    /// 是否正在删除
    @State private var isDeleting = false

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 地图预览
                    mapPreview

                    // 领地信息卡片
                    infoCard

                    // 未来功能占位
                    futureFeaturesCard

                    // 删除按钮
                    deleteButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(territory.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        await deleteTerritory()
                    }
                }
            } message: {
                Text("确定要删除这块领地吗？此操作无法撤销。")
            }
        }
    }

    // MARK: - 子视图

    /// 地图预览
    private var mapPreview: some View {
        // 获取转换后的坐标（GCJ-02）
        let coords = CoordinateConverter.wgs84ToGcj02(territory.coordinates)

        return Map {
            // 绘制领地多边形
            if coords.count >= 3 {
                MapPolygon(coordinates: coords)
                    .foregroundStyle(.green.opacity(0.3))
                    .stroke(.green, lineWidth: 2)
            }
        }
        .mapStyle(.imagery)
        .frame(height: 200)
        .cornerRadius(12)
        .disabled(true)  // 禁止交互
    }

    /// 领地信息卡片
    private var infoCard: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                Text("领地信息")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // 信息行
            VStack(spacing: 0) {
                InfoRow(label: "面积", value: territory.formattedArea)
                Divider().padding(.leading)
                InfoRow(label: "路径点数", value: "\(territory.pointCount) 个")
                Divider().padding(.leading)
                InfoRow(label: "创建时间", value: territory.formattedCreatedAt)
                if territory.completedAt != nil {
                    Divider().padding(.leading)
                    InfoRow(label: "状态", value: territory.isActive ? "激活" : "未激活")
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    /// 未来功能占位卡片
    private var futureFeaturesCard: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                Text("更多功能")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // 功能列表
            VStack(spacing: 0) {
                FutureFeatureRow(icon: "pencil", title: "重命名领地", subtitle: "敬请期待")
                Divider().padding(.leading, 56)
                FutureFeatureRow(icon: "building.2", title: "建筑系统", subtitle: "敬请期待")
                Divider().padding(.leading, 56)
                FutureFeatureRow(icon: "arrow.left.arrow.right", title: "领地交易", subtitle: "敬请期待")
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
                Text(isDeleting ? "删除中..." : "删除领地")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isDeleting)
        .padding(.top, 20)
    }

    // MARK: - 方法

    /// 删除领地
    private func deleteTerritory() async {
        isDeleting = true

        let success = await territoryManager.deleteTerritory(territoryId: territory.id)

        isDeleting = false

        if success {
            onDelete?()
            dismiss()
        }
    }
}

// MARK: - 信息行组件

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
        .padding()
    }
}

// MARK: - 未来功能行组件

struct FutureFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
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
}
