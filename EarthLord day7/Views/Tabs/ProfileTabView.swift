//
//  ProfileTabView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI
import Supabase

struct ProfileTabView: View {
    @EnvironmentObject private var authManager: AuthManager

    /// 是否显示登出确认弹窗
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // 用户信息卡片
                        userInfoCard

                        // 统计信息（占位）
                        statisticsSection

                        // 功能菜单
                        menuSection

                        // 退出登录按钮
                        signOutButton

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("个人")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("退出登录", isPresented: $showSignOutAlert) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text("确定要退出登录吗？")
        }
    }

    // MARK: - 用户信息卡片

    private var userInfoCard: some View {
        VStack(spacing: 16) {
            // 头像
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ApocalypseTheme.primary,
                            ApocalypseTheme.primary.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 20)

            // 用户名
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(displayEmail)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 用户ID
            Text("ID: \(authManager.currentUser?.id.uuidString.prefix(8) ?? "Unknown")")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 统计信息

    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statisticsItem(icon: "flag.fill", title: "领地", value: "0")
                statisticsItem(icon: "map.fill", title: "探索", value: "0")
            }

            HStack(spacing: 12) {
                statisticsItem(icon: "cube.fill", title: "建筑", value: "0")
                statisticsItem(icon: "star.fill", title: "成就", value: "0")
            }
        }
    }

    private func statisticsItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ApocalypseTheme.primary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - 功能菜单

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuItem(icon: "gearshape.fill", iconColor: .gray, title: "设置") {
                // TODO: 导航到设置页面
                print("点击设置")
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            menuItem(icon: "bell.fill", iconColor: .orange, title: "通知") {
                // TODO: 导航到通知页面
                print("点击通知")
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            menuItem(icon: "questionmark.circle.fill", iconColor: .blue, title: "帮助") {
                // TODO: 导航到帮助页面
                print("点击帮助")
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            menuItem(icon: "info.circle.fill", iconColor: .green, title: "关于") {
                // TODO: 导航到关于页面
                print("点击关于")
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func menuItem(icon: String, iconColor: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 30)

                // 标题
                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                // 右侧箭头
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 退出登录按钮

    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("退出登录")
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.danger)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ApocalypseTheme.danger.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - 计算属性

    /// 显示名称
    private var displayName: String {
        if let metadata = authManager.currentUser?.userMetadata,
           let name = metadata["name"] as? String {
            return name
        }
        return authManager.currentUser?.email?.components(separatedBy: "@").first?.capitalized ?? "开拓者"
    }

    /// 显示邮箱
    private var displayEmail: String {
        authManager.currentUser?.email ?? "未知邮箱"
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(AuthManager())
}
