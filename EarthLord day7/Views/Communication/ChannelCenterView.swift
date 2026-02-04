//
//  ChannelCenterView.swift
//  EarthLord day7
//
//  频道中心页面
//

import SwiftUI
import Supabase

struct ChannelCenterView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedTab = 0 // 0: 我的频道, 1: 发现频道
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var selectedChannel: CommunicationChannel?
    @State private var navigateToChatChannel: CommunicationChannel?
    @State private var navigateToOfficialChannel = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部标题栏
                headerView

                // Tab 切换栏
                tabBar

                // 内容区域
                if selectedTab == 0 {
                    myChannelsView
                } else {
                    discoverChannelsView
                }
            }
            .background(ApocalypseTheme.background)
            .sheet(isPresented: $showCreateSheet) {
                CreateChannelSheet()
                    .environmentObject(authManager)
            }
            .sheet(item: $selectedChannel) { channel in
                ChannelDetailView(channel: channel)
                    .environmentObject(authManager)
            }
            .navigationDestination(item: $navigateToChatChannel) { channel in
                ChannelChatView(channel: channel)
                    .environmentObject(authManager)
            }
            .navigationDestination(isPresented: $navigateToOfficialChannel) {
                OfficialChannelDetailView()
                    .environmentObject(authManager)
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - 顶部标题栏

    private var headerView: some View {
        HStack {
            Text("频道中心")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.surface)
    }

    // MARK: - Tab 切换栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的频道", index: 0)
            tabButton(title: "发现频道", index: 1)
        }
        .background(ApocalypseTheme.surface)
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(selectedTab == index ? .semibold : .regular)
                    .foregroundColor(selectedTab == index ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)

                Rectangle()
                    .fill(selectedTab == index ? ApocalypseTheme.primary : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }

    // MARK: - 我的频道

    private var myChannelsView: some View {
        Group {
            if communicationManager.isLoading {
                loadingView
            } else if communicationManager.subscribedChannels.isEmpty {
                emptyMyChannelsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // 官方频道置顶入口
                        if let officialChannel = communicationManager.getOfficialChannel() {
                            OfficialChannelEntryCard(channel: officialChannel)
                                .onTapGesture {
                                    navigateToOfficialChannel = true
                                }
                        }

                        // 其他订阅的频道
                        ForEach(communicationManager.subscribedChannels.filter { !communicationManager.isOfficialChannel($0.channel.id) }) { subscribedChannel in
                            ChannelRowView(channel: subscribedChannel.channel, isSubscribed: true)
                                .onTapGesture {
                                    // 订阅的频道点击进入聊天
                                    navigateToChatChannel = subscribedChannel.channel
                                }
                                .onLongPressGesture {
                                    // 长按查看详情
                                    selectedChannel = subscribedChannel.channel
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var emptyMyChannelsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("还没有订阅任何频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("去「发现频道」探索更多")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Button {
                selectedTab = 1
            } label: {
                Text("发现频道")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(8)
            }
            Spacer()
        }
    }

    // MARK: - 发现频道

    private var discoverChannelsView: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar

            if communicationManager.isLoading {
                loadingView
            } else if filteredChannels.isEmpty {
                emptyDiscoverView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredChannels) { channel in
                            ChannelRowView(
                                channel: channel,
                                isSubscribed: communicationManager.isSubscribed(channelId: channel.id)
                            )
                            .onTapGesture {
                                selectedChannel = channel
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ApocalypseTheme.textSecondary)
            TextField("搜索频道", text: $searchText)
                .foregroundColor(ApocalypseTheme.textPrimary)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(ApocalypseTheme.surface)
        .cornerRadius(10)
        .padding()
    }

    private var emptyDiscoverView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "globe")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text(searchText.isEmpty ? "暂无公开频道" : "没有找到匹配的频道")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("创建第一个频道吧！")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
    }

    // MARK: - 通用视图

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

    // MARK: - 计算属性

    private var filteredChannels: [CommunicationChannel] {
        if searchText.isEmpty {
            return communicationManager.channels
        }
        return communicationManager.channels.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.channelCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - 方法

    private func loadData() async {
        guard let userId = authManager.currentUser?.id else { return }
        await communicationManager.loadPublicChannels()
        await communicationManager.loadSubscribedChannels(userId: userId)
    }
}

// MARK: - 频道行视图

struct ChannelRowView: View {
    let channel: CommunicationChannel
    let isSubscribed: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channelTypeColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: channel.channelType.iconName)
                    .font(.title3)
                    .foregroundColor(channelTypeColor)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    if isSubscribed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.success)
                    }
                }
                Text(channel.channelCode)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                HStack(spacing: 8) {
                    Label("\(channel.memberCount)", systemImage: "person.2.fill")
                        .font(.caption2)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text(channel.channelType.displayName)
                        .font(.caption2)
                        .foregroundColor(channelTypeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(channelTypeColor.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.surface)
        .cornerRadius(12)
    }

    private var channelTypeColor: Color {
        switch channel.channelType {
        case .official: return ApocalypseTheme.warning
        case .publicChannel: return ApocalypseTheme.primary
        case .walkie: return ApocalypseTheme.success
        case .camp: return ApocalypseTheme.secondary
        case .satellite: return ApocalypseTheme.info
        }
    }
}

// MARK: - 官方频道入口卡片

struct OfficialChannelEntryCard: View {
    let channel: CommunicationChannel

    var body: some View {
        HStack(spacing: 12) {
            // 官方图标
            ZStack {
                Circle()
                    .fill(ApocalypseTheme.warning.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "megaphone.fill")
                    .font(.title3)
                    .foregroundColor(ApocalypseTheme.warning)
            }

            // 频道信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(channel.name)
                        .font(.headline)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.warning)
                }
                Text("官方公告和游戏资讯")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ApocalypseTheme.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ChannelCenterView()
        .environmentObject(AuthManager())
}
