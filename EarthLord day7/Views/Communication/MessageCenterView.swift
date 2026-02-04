//
//  MessageCenterView.swift
//  EarthLord day7
//
//  消息聚合中心页面
//

import SwiftUI
import Auth

struct MessageCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var isLoading = true
    @State private var navigateToChannel: CommunicationChannel?
    @State private var navigateToOfficialChannel = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 标题栏
                headerView

                // 频道摘要列表
                channelListView
            }
            .background(ApocalypseTheme.background)
            .navigationDestination(isPresented: $navigateToOfficialChannel) {
                OfficialChannelDetailView()
                    .environmentObject(authManager)
            }
            .navigationDestination(item: $navigateToChannel) { channel in
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("消息中心")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("查看所有订阅频道的最新消息")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Spacer()
        }
        .padding()
        .background(ApocalypseTheme.surface)
    }

    // MARK: - 频道列表

    private var channelListView: some View {
        Group {
            if isLoading {
                loadingView
            } else if channelSummaries.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(channelSummaries) { summary in
                            ChannelSummaryCard(summary: summary)
                                .onTapGesture {
                                    handleChannelTap(summary.channel)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var channelSummaries: [ChannelSummary] {
        communicationManager.getChannelSummaries()
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("订阅频道后，消息将显示在这里")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - 方法

    private func loadData() async {
        isLoading = true
        if let userId = authManager.currentUser?.id {
            await communicationManager.loadSubscribedChannels(userId: userId)
            await communicationManager.loadAllChannelLatestMessages()
        }
        isLoading = false
    }

    private func handleChannelTap(_ channel: CommunicationChannel) {
        if communicationManager.isOfficialChannel(channel.id) {
            navigateToOfficialChannel = true
        } else {
            navigateToChannel = channel
        }
    }
}

// MARK: - 频道摘要卡片

struct ChannelSummaryCard: View {
    let summary: ChannelSummary

    private var isOfficial: Bool {
        summary.channel.id == CommunicationManager.officialChannelId
    }

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channelColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: summary.channel.channelType.iconName)
                    .font(.title3)
                    .foregroundColor(channelColor)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(summary.channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    if isOfficial {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.warning)
                    }
                }

                if let lastMessage = summary.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("暂无消息")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textMuted)
                        .italic()
                }
            }

            Spacer()

            // 时间和未读
            VStack(alignment: .trailing, spacing: 4) {
                if let lastMessage = summary.lastMessage {
                    Text(lastMessage.timeAgo)
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }

                if summary.unreadCount > 0 {
                    Text("\(summary.unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ApocalypseTheme.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isOfficial ? ApocalypseTheme.warning.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var channelColor: Color {
        switch summary.channel.channelType {
        case .official: return ApocalypseTheme.warning
        case .publicChannel: return ApocalypseTheme.primary
        case .walkie: return ApocalypseTheme.success
        case .camp: return ApocalypseTheme.secondary
        case .satellite: return ApocalypseTheme.info
        }
    }
}

#Preview {
    MessageCenterView()
        .environmentObject(AuthManager())
}
