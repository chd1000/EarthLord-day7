//
//  ChannelChatView.swift
//  EarthLord day7
//
//  频道聊天界面
//

import SwiftUI
import Auth

struct ChannelChatView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var messageText = ""
    @State private var isLoading = true
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            messageListView

            // 输入栏或收音机提示
            if communicationManager.canSendMessage() {
                chatInputBar
            } else {
                radioModeHint
            }
        }
        .background(ApocalypseTheme.background)
        .navigationTitle(channel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(channel.memberCount)")
                        .font(.caption)
                }
                .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .task {
            await loadMessages()
            await communicationManager.startRealtimeSubscription()
            communicationManager.subscribeToChannelMessages(channelId: channel.id)
        }
        .onDisappear {
            communicationManager.unsubscribeFromChannelMessages(channelId: channel.id)
        }
    }

    // MARK: - 消息列表

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.primary))
                            .padding(.top, 50)
                    } else if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isOwnMessage: message.senderId == authManager.currentUser?.id
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(ApocalypseTheme.textSecondary.opacity(0.5))
            Text("暂无消息")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("成为第一个发言的幸存者")
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - 输入栏

    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("输入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(20)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .focused($isInputFocused)
                .lineLimit(1...5)

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: communicationManager.isSendingMessage ? "hourglass" : "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundColor(canSend ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
            }
            .disabled(!canSend || communicationManager.isSendingMessage)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ApocalypseTheme.surface)
    }

    // MARK: - 收音机模式提示

    private var radioModeHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "radio")
                .font(.system(size: 16))
            Text("收音机模式：只能收听，无法发送消息")
                .font(.subheadline)
        }
        .foregroundColor(ApocalypseTheme.textSecondary)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.surface)
    }

    // MARK: - 计算属性

    private var messages: [ChannelMessage] {
        communicationManager.getMessages(for: channel.id)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 方法

    private func loadMessages() async {
        isLoading = true
        await communicationManager.loadChannelMessages(channelId: channel.id)
        isLoading = false
    }

    private func sendMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let deviceType = communicationManager.getCurrentDeviceType().rawValue

        let success = await communicationManager.sendChannelMessage(
            channelId: channel.id,
            content: content,
            latitude: nil,
            longitude: nil,
            deviceType: deviceType
        )

        if success {
            messageText = ""
            isInputFocused = false
        }
    }
}

// MARK: - 消息气泡视图

struct MessageBubbleView: View {
    let message: ChannelMessage
    let isOwnMessage: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                // 呼号（仅他人消息显示）
                if !isOwnMessage {
                    Text(message.senderCallsign ?? "匿名幸存者")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.primary)
                }

                // 消息内容
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isOwnMessage ? .white : ApocalypseTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isOwnMessage
                            ? ApocalypseTheme.primary
                            : ApocalypseTheme.cardBackground
                    )
                    .cornerRadius(16)

                // 时间
                Text(message.timeAgo)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChannelChatView(channel: CommunicationChannel(
            id: UUID(),
            creatorId: UUID(),
            channelType: .publicChannel,
            channelCode: "TEST-001",
            name: "测试频道",
            description: "这是一个测试频道",
            isActive: true,
            memberCount: 42,
            createdAt: Date(),
            updatedAt: Date()
        ))
        .environmentObject(AuthManager())
    }
}
