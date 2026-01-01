//
//  MainTabView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTabView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text(languageManager.localizedString("地图"))
                }
                .tag(0)

            TerritoryTabView()
                .tabItem {
                    Image(systemName: "flag.fill")
                    Text(languageManager.localizedString("领地"))
                }
                .tag(1)

            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text(languageManager.localizedString("个人"))
                }
                .tag(2)

            MoreTabView()
                .tabItem {
                    Image(systemName: "ellipsis")
                    Text(languageManager.localizedString("更多"))
                }
                .tag(3)
        }
        .tint(ApocalypseTheme.primary)
        // 当语言改变时强制刷新整个 TabView
        .id(languageManager.currentLanguageCode)
    }
}

#Preview {
    MainTabView()
        .environmentObject(LanguageManager.shared)
}
