//
//  MoreTabView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI

struct MoreTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Supabase 测试入口
                    NavigationLink(destination: SupabaseTestView()) {
                        HStack {
                            Image(systemName: "server.rack")
                                .font(.title2)
                                .foregroundColor(ApocalypseTheme.primary)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Supabase 连接测试")
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                                Text("检测数据库连接状态")
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
            .navigationTitle("更多")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    MoreTabView()
}
