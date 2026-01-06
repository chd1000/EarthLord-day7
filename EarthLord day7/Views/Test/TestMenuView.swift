//
//  TestMenuView.swift
//  EarthLord day7
//
//  测试模块入口菜单
//  提供各种测试功能的入口
//
//  ⚠️ 注意：此视图不套 NavigationStack，因为它已经在父级导航栈内
//

import SwiftUI

/// 测试模块入口菜单
struct TestMenuView: View {

    // MARK: - 环境对象
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 列表
            List {
                // Supabase 连接测试
                NavigationLink {
                    SupabaseTestView()
                } label: {
                    testMenuItem(
                        icon: "server.rack",
                        iconColor: .blue,
                        title: languageManager.localizedString("Supabase 连接测试"),
                        subtitle: languageManager.localizedString("检测数据库连接状态")
                    )
                }
                .listRowBackground(ApocalypseTheme.cardBackground)

                // 圈地功能测试
                NavigationLink {
                    TerritoryTestView()
                } label: {
                    testMenuItem(
                        icon: "flag.fill",
                        iconColor: ApocalypseTheme.primary,
                        title: languageManager.localizedString("圈地功能测试"),
                        subtitle: languageManager.localizedString("查看圈地模块运行日志")
                    )
                }
                .listRowBackground(ApocalypseTheme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle(languageManager.localizedString("开发测试"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - 列表项视图

    private func testMenuItem(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            // 图标
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)

            // 文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        TestMenuView()
            .environmentObject(LanguageManager.shared)
    }
}
