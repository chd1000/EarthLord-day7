//
//  SettingsView.swift
//  EarthLord day7
//
//  设置页面
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager

    /// 是否显示语言选择弹窗
    @State private var showLanguagePicker = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 语言设置
                    languageSettingRow

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(languageManager.localizedString("设置"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLanguagePicker) {
            languagePickerSheet
        }
    }

    // MARK: - 语言设置行

    private var languageSettingRow: some View {
        Button {
            showLanguagePicker = true
        } label: {
            HStack {
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(languageManager.localizedString("语言"))
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Text(languageManager.localizedString("切换应用显示语言"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                Spacer()

                Text(languageManager.selectedLanguage.localizedDisplayName(for: languageManager.currentLanguageCode))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Image(systemName: "chevron.right")
                    .foregroundColor(ApocalypseTheme.textMuted)
            }
            .padding()
            .background(ApocalypseTheme.cardBackground)
            .cornerRadius(12)
        }
    }

    // MARK: - 语言选择弹窗

    private var languagePickerSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases, id: \.rawValue) { language in
                        languageOptionRow(language)
                    }

                    Spacer()

                    // 提示信息
                    Text(languageManager.localizedString("语言切换提示"))
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding(.top)
            }
            .navigationTitle(languageManager.localizedString("选择语言"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(languageManager.localizedString("完成")) {
                        showLanguagePicker = false
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// 语言选项行
    private func languageOptionRow(_ language: AppLanguage) -> some View {
        Button {
            languageManager.selectedLanguage = language
            // 延迟关闭，让用户看到选择效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showLanguagePicker = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.localizedDisplayName(for: languageManager.currentLanguageCode))
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if language == .system {
                        Text(languageManager.localizedString("根据系统语言自动切换"))
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }

                Spacer()

                if languageManager.selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.primary)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                languageManager.selectedLanguage == language
                    ? ApocalypseTheme.primary.opacity(0.1)
                    : ApocalypseTheme.cardBackground
            )
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
