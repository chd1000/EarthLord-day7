//
//  TerritoryToolbarView.swift
//  EarthLord day7
//
//  悬浮工具栏组件
//  包含关闭按钮、建造按钮、信息面板切换
//

import SwiftUI

/// 领地工具栏
struct TerritoryToolbarView: View {

    // MARK: - 参数

    /// 领地名称
    let territoryName: String

    /// 关闭回调
    var onClose: (() -> Void)?

    /// 建造回调
    var onBuild: (() -> Void)?

    /// 切换信息面板回调
    var onToggleInfo: (() -> Void)?

    /// 信息面板是否显示
    var isInfoPanelVisible: Bool

    // MARK: - 视图

    var body: some View {
        HStack(spacing: 12) {
            // 关闭按钮
            toolbarButton(icon: "xmark", action: onClose)

            Spacer()

            // 领地名称
            Text(territoryName)
                .font(.headline)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2)

            Spacer()

            // 建造按钮
            toolbarButton(icon: "hammer.fill", action: onBuild)

            // 信息面板切换按钮
            toolbarButton(
                icon: isInfoPanelVisible ? "chevron.down" : "chevron.up",
                action: onToggleInfo
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.black.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 子视图

    /// 工具栏按钮
    private func toolbarButton(icon: String, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
        }
    }
}

// MARK: - 预览

#Preview {
    ZStack {
        Color.gray

        VStack {
            TerritoryToolbarView(
                territoryName: "我的领地",
                onClose: { },
                onBuild: { },
                onToggleInfo: { },
                isInfoPanelVisible: true
            )

            Spacer()
        }
    }
    .ignoresSafeArea()
}
