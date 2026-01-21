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
                    Spacer()

                    // 敬请期待
                    VStack(spacing: 16) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 50))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(languageManager.localizedString("敬请期待"))
                            .font(.headline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
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
