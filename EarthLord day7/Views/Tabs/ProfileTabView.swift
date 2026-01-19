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
    @EnvironmentObject private var languageManager: LanguageManager

    /// 是否显示登出确认弹窗
    @State private var showSignOutAlert = false

    init() {
        // 设置导航栏外观（橙色标题）- 使用 ApocalypseTheme.primary 的颜色值
        let primaryOrange = UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1.0)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        appearance.largeTitleTextAttributes = [
            .foregroundColor: primaryOrange
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: primaryOrange
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    /// 是否显示删除账户确认弹窗
    @State private var showDeleteAccountAlert = false

    /// 删除确认输入文字
    @State private var deleteConfirmText = ""

    /// 是否显示删除成功提示
    @State private var showDeleteSuccessAlert = false

    /// 删除确认关键词（根据当前语言）
    private var deleteConfirmKeyword: String {
        languageManager.currentLanguageCode == "en" ? "Delete" : "删除"
    }

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

                        // 删除账户按钮
                        deleteAccountButton

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle(languageManager.localizedString("个人"))
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(ApocalypseTheme.primary)
        .alert(languageManager.localizedString("退出登录"), isPresented: $showSignOutAlert) {
            Button(languageManager.localizedString("取消"), role: .cancel) {}
            Button(languageManager.localizedString("退出"), role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            }
        } message: {
            Text(languageManager.localizedString("确定要退出登录吗？"))
        }
        .sheet(isPresented: $showDeleteAccountAlert) {
            deleteAccountConfirmSheet
        }
        .alert(languageManager.localizedString("账户删除成功"), isPresented: $showDeleteSuccessAlert) {
            Button(languageManager.localizedString("确定"), role: .cancel) {}
        } message: {
            Text(languageManager.localizedString("您的账户已被永久删除，感谢您的使用。"))
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
            Text(languageManager.localizedString("ID: %@", String(authManager.currentUser?.id.uuidString.prefix(8) ?? "Unknown")))
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
                statisticsItem(icon: "flag.fill", title: languageManager.localizedString("领地"), value: "0")
                statisticsItem(icon: "map.fill", title: languageManager.localizedString("探索"), value: "0")
            }

            HStack(spacing: 12) {
                statisticsItem(icon: "cube.fill", title: languageManager.localizedString("建筑"), value: "0")
                statisticsItem(icon: "star.fill", title: languageManager.localizedString("成就"), value: "0")
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
            // 设置 - 使用 NavigationLink
            NavigationLink(destination: SettingsView()) {
                HStack(spacing: 16) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                        .frame(width: 30)

                    Text(languageManager.localizedString("设置"))
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            menuItem(icon: "bell.fill", iconColor: .orange, title: languageManager.localizedString("通知")) {
                // TODO: 导航到通知页面
                print("点击通知")
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            menuItem(icon: "questionmark.circle.fill", iconColor: .blue, title: languageManager.localizedString("帮助")) {
                // TODO: 导航到帮助页面
                print("点击帮助")
            }

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            menuItem(icon: "info.circle.fill", iconColor: .green, title: languageManager.localizedString("关于")) {
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
                Text(languageManager.localizedString("退出登录"))
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

    // MARK: - 删除账户按钮

    private var deleteAccountButton: some View {
        Button {
            print("🔵 [删除账户] 用户点击删除账户按钮")
            deleteConfirmText = ""
            showDeleteAccountAlert = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                Text(languageManager.localizedString("删除账户"))
            }
            .font(.headline)
            .foregroundColor(ApocalypseTheme.textMuted)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.cardBackground.opacity(0.5))
            .cornerRadius(12)
        }
    }

    // MARK: - 删除账户确认弹窗

    private var deleteAccountConfirmSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ApocalypseTheme.danger)
                        .padding(.top, 20)

                    // 警告标题
                    Text(languageManager.localizedString("删除账户"))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    // 警告说明
                    VStack(spacing: 12) {
                        Text(languageManager.localizedString("此操作不可撤销！"))
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.danger)

                        Text(languageManager.localizedString("删除账户后，您的所有数据将被永久删除，包括："))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                            .multilineTextAlignment(.center)

                        VStack(alignment: .leading, spacing: 8) {
                            deleteWarningItem(languageManager.localizedString("个人资料和设置"))
                            deleteWarningItem(languageManager.localizedString("游戏进度和成就"))
                            deleteWarningItem(languageManager.localizedString("领地和建筑数据"))
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // 确认输入框
                    VStack(alignment: .leading, spacing: 8) {
                        Text(languageManager.localizedString("请输入「删除」以确认："))
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        TextField(deleteConfirmKeyword, text: $deleteConfirmText)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(ApocalypseTheme.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        deleteConfirmText == deleteConfirmKeyword ? ApocalypseTheme.danger : ApocalypseTheme.textMuted.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                            .foregroundColor(ApocalypseTheme.textPrimary)
                    }
                    .padding(.horizontal)

                    Spacer()

                    // 按钮组
                    VStack(spacing: 12) {
                        // 确认删除按钮
                        Button {
                            print("🔵 [删除账户] 用户确认删除，输入内容: \(deleteConfirmText)")
                            Task {
                                let success = await authManager.deleteAccount()
                                if success {
                                    print("✅ [删除账户] 删除成功，关闭弹窗并显示成功提示")
                                    showDeleteAccountAlert = false
                                    // 延迟显示成功提示，等待 sheet 关闭动画完成
                                    try? await Task.sleep(nanoseconds: 300_000_000)
                                    showDeleteSuccessAlert = true
                                } else {
                                    print("❌ [删除账户] 删除失败")
                                }
                            }
                        } label: {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "trash.fill")
                                    Text(languageManager.localizedString("确认删除"))
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(deleteConfirmText == deleteConfirmKeyword ? ApocalypseTheme.danger : ApocalypseTheme.textMuted)
                            .cornerRadius(12)
                        }
                        .disabled(deleteConfirmText != deleteConfirmKeyword || authManager.isLoading)

                        // 取消按钮
                        Button {
                            print("🔵 [删除账户] 用户取消删除")
                            showDeleteAccountAlert = false
                        } label: {
                            Text(languageManager.localizedString("取消"))
                                .font(.headline)
                                .foregroundColor(ApocalypseTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    /// 删除警告项
    private func deleteWarningItem(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(ApocalypseTheme.danger)
                .font(.caption)
            Text(text)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
    }

    // MARK: - 计算属性

    /// 显示名称
    private var displayName: String {
        if let metadata = authManager.currentUser?.userMetadata,
           let nameJSON = metadata["name"],
           case .string(let name) = nameJSON {
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
        .environmentObject(LanguageManager.shared)
}
