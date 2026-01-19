//
//  MoreTabView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // 开发测试入口
                    NavigationLink(destination: TestMenuView()) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .font(.title2)
                                .foregroundColor(ApocalypseTheme.primary)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(languageManager.localizedString("开发测试"))
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                Text(languageManager.localizedString("查看调试信息和测试功能"))
                                    .font(.caption)
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(ApocalypseTheme.textMuted)
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(languageManager.localizedString("更多"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    MoreTabView()
        .environmentObject(LanguageManager.shared)
}
