//
//  ChannelDetailView.swift
//  EarthLord day7
//
//  频道详情页面
//

import SwiftUI
import Supabase

struct ChannelDetailView: View {
    let channel: CommunicationChannel

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var isProcessing = false

    private var isCreator: Bool {
        authManager.currentUser?.id == channel.creatorId
    }

    private var isSubscribed: Bool {
        communicationManager.isSubscribed(channelId: channel.id)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道头像和基本信息
                    headerSection

                    // 频道信息卡片
                    infoCard

                    // 操作按钮
                    actionButtons

                    // 错误信息
                    if let error = communicationManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.error)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(ApocalypseTheme.background)
            .navigationTitle("频道详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task {
                        await deleteChannel()
                    }
                }
            } message: {
                Text("删除频道后无法恢复，所有订阅者将自动取消订阅。确定要删除「\(channel.name)」吗？")
            }
        }
    }

    // MARK: - 头部信息

    private var headerSection: some View {
        VStack(spacing: 16) {
            // 频道图标
            ZStack {
                Circle()
                    .fill(channelTypeColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: channel.channelType.iconName)
                    .font(.system(size: 36))
                    .foregroundColor(channelTypeColor)
            }

            // 频道名称
            Text(channel.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 频道码
            HStack(spacing: 8) {
                Text(channel.channelCode)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ApocalypseTheme.textSecondary)

                Button {
                    UIPasteboard.general.string = channel.channelCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ApocalypseTheme.surface)
            .cornerRadius(20)

            // 订阅状态
            if isSubscribed {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("已订阅")
                }
                .font(.caption)
                .foregroundColor(ApocalypseTheme.success)
            }
        }
    }

    // MARK: - 信息卡片

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(title: "频道类型", value: channel.channelType.displayName, icon: channel.channelType.iconName, color: channelTypeColor)
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
            infoRow(title: "成员数量", value: "\(channel.memberCount) 人", icon: "person.2.fill", color: ApocalypseTheme.primary)
            Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
            infoRow(title: "创建时间", value: formatDate(channel.createdAt), icon: "calendar", color: ApocalypseTheme.textSecondary)

            if let description = channel.description, !description.isEmpty {
                Divider().background(ApocalypseTheme.textSecondary.opacity(0.2))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Text("频道描述")
                            .font(.subheadline)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                    Text(description)
                        .font(.body)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
        }
        .background(ApocalypseTheme.surface)
        .cornerRadius(12)
    }

    private func infoRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
    }

    // MARK: - 操作按钮

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isCreator {
                // 创建者：显示删除按钮
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("删除频道")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.error.opacity(0.15))
                    .foregroundColor(ApocalypseTheme.error)
                    .cornerRadius(12)
                }
            } else {
                // 非创建者：显示订阅/取消按钮
                if isSubscribed {
                    Button {
                        Task {
                            await unsubscribe()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ApocalypseTheme.warning))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bell.slash.fill")
                            }
                            Text(isProcessing ? "处理中..." : "取消订阅")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ApocalypseTheme.warning.opacity(0.15))
                        .foregroundColor(ApocalypseTheme.warning)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                } else {
                    Button {
                        Task {
                            await subscribe()
                        }
                    } label: {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "bell.fill")
                            }
                            Text(isProcessing ? "处理中..." : "订阅频道")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ApocalypseTheme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    // MARK: - 计算属性

    private var channelTypeColor: Color {
        switch channel.channelType {
        case .official: return ApocalypseTheme.warning
        case .publicChannel: return ApocalypseTheme.primary
        case .walkie: return ApocalypseTheme.success
        case .camp: return ApocalypseTheme.secondary
        case .satellite: return ApocalypseTheme.info
        }
    }

    // MARK: - 方法

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func subscribe() async {
        guard let userId = authManager.currentUser?.id else { return }
        isProcessing = true
        await communicationManager.subscribeToChannel(userId: userId, channelId: channel.id)
        isProcessing = false
    }

    private func unsubscribe() async {
        guard let userId = authManager.currentUser?.id else { return }
        isProcessing = true
        await communicationManager.unsubscribeFromChannel(userId: userId, channelId: channel.id)
        isProcessing = false
        dismiss()
    }

    private func deleteChannel() async {
        isProcessing = true
        await communicationManager.deleteChannel(channelId: channel.id)
        isProcessing = false
        dismiss()
    }
}

#Preview {
    ChannelDetailView(channel: CommunicationChannel(
        id: UUID(),
        creatorId: UUID(),
        channelType: .publicChannel,
        channelCode: "PUB-ABC123",
        name: "测试频道",
        description: "这是一个测试频道的描述文字",
        isActive: true,
        memberCount: 42,
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(AuthManager())
}
