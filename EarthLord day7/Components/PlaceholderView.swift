//
//  PlaceholderView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI

/// 通用占位视图
struct PlaceholderView: View {
    @EnvironmentObject var languageManager: LanguageManager

    let icon: String
    let titleKey: String
    let subtitleKey: String

    init(icon: String, title: String, subtitle: String) {
        self.icon = icon
        self.titleKey = title
        self.subtitleKey = subtitle
    }

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(languageManager.localizedString(titleKey))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(languageManager.localizedString(subtitleKey))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
    }
}

#Preview {
    PlaceholderView(
        icon: "map.fill",
        title: "地图",
        subtitle: "探索和圈占领地"
    )
    .environmentObject(LanguageManager.shared)
}
