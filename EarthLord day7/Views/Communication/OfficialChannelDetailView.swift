//
//  OfficialChannelDetailView.swift
//  EarthLord day7
//
//  官方频道详情页（带分类过滤）
//

import SwiftUI

struct OfficialChannelDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedCategory: MessageCategory?
    @State private var isLoading = true

    private let officialChannelId = CommunicationManager.officialChannelId

    var body: some View {
        VStack(spacing: 0) {
            // 分类过滤栏
            categoryFilterBar

            // 消息列表
            messageListView
        }
        .background(ApocalypseTheme.background)
        .navigationTitle("末日广播")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(ApocalypseTheme.warning)
            }
        }
        .task {
            await loadMessages()
            await communicationManager.startRealtimeSubscription()
            communicationManager.subscribeToChannelMessages(channelId: officialChannelId)
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: officialChannelId)
        }
    }

    // MARK: - 分类过滤栏

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 全部
                categoryButton(nil, title: "全部", iconName: "list.bullet")

                // 各分类
                ForEach(MessageCategory.allCases, id: \.self) { category in
                    categoryButton(category, title: category.displayName, iconName: category.iconName)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(ApocalypseTheme.surface)
    }

    private func categoryButton(_ category: MessageCategory?, title: String, iconName: String) -> some View {
        let isSelected = selectedCategory == category
        let color = category?.color ?? ApocalypseTheme.primary

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(20)
        }
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                        .padding(.top, 50)
                } else if filteredMessages.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredMessages) { message in
                        OfficialMessageCard(message: message)
                    }
                }
            }
            .padding()
        }
    }

    private var filteredMessages: [ChannelMessage] {
        let allMessages = communicationManager.getMessages(for: officialChannelId)
        if let category = selectedCategory {
            return allMessages.filter { $0.category == category }
        }
        return allMessages
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "megaphone")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无公告")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text(selectedCategory == nil ? "官方公告将在这里发布" : "暂无该分类的公告")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private func loadMessages() async {
        isLoading = true
        await communicationManager.loadChannelMessages(channelId: officialChannelId)
        isLoading = false
    }
}

// MARK: - 官方消息卡片

struct OfficialMessageCard: View {
    let message: ChannelMessage

    private var category: MessageCategory {
        message.category ?? .news
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部：分类标签 + 时间
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: category.iconName)
                        .font(.system(size: 12))
                    Text(category.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(category.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(category.color.opacity(0.15))
                .cornerRadius(12)

                Spacer()

                Text(message.timeAgo)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            // 内容
            Text(message.content)
                .font(.body)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            // 底部：发送者信息
            HStack {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 12))
                Text(message.senderCallsign ?? "官方")
                    .font(.caption)
            }
            .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        OfficialChannelDetailView()
            .environmentObject(AuthManager())
    }
}
