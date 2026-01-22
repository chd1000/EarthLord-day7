//
//  AboutView.swift
//  EarthLord day7
//
//  关于页面 - 显示技术支持和隐私政策链接
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    /// 应用版本号
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 构建版本号
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // App 图标和名称
                    appInfoSection

                    // 链接按钮
                    linksSection

                    // 版权信息
                    copyrightSection
                }
                .padding()
            }
        }
        .navigationTitle(languageManager.localizedString("关于"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - App 信息

    private var appInfoSection: some View {
        VStack(spacing: 16) {
            // App 图标
            Image("AppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 10)

            // App 名称
            Text("Earth Lord")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 版本信息
            Text(languageManager.localizedString("版本 %@（%@）", appVersion, buildNumber))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 链接部分

    private var linksSection: some View {
        VStack(spacing: 0) {
            // 技术支持
            linkItem(
                icon: "wrench.and.screwdriver.fill",
                iconColor: .blue,
                title: languageManager.localizedString("技术支持"),
                url: "https://chd1000.github.io/earthlord-support/"
            )

            Divider()
                .background(ApocalypseTheme.textMuted.opacity(0.2))
                .padding(.horizontal)

            // 隐私政策
            linkItem(
                icon: "hand.raised.fill",
                iconColor: .green,
                title: languageManager.localizedString("隐私政策"),
                url: "https://chd1000.github.io/earthlord-support/privacy.html"
            )
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }

    private func linkItem(icon: String, iconColor: Color, title: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 30)

                Text(title)
                    .font(.body)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - 版权信息

    private var copyrightSection: some View {
        VStack(spacing: 8) {
            Text("© 2025 Earth Lord")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(languageManager.localizedString("保留所有权利"))
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textMuted.opacity(0.7))
        }
        .padding(.top, 20)
    }
}

#Preview {
    NavigationStack {
        AboutView()
            .environmentObject(LanguageManager.shared)
    }
}
