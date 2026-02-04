//
//  PTTCallView.swift
//  EarthLord day7
//
//  PTT通话界面
//

import SwiftUI
import Auth
import CoreLocation

struct PTTCallView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var selectedChannel: SubscribedChannel?
    @State private var isPressing = false
    @State private var pressStartTime: Date?
    @State private var messageText = ""
    @State private var isSending = false
    @FocusState private var isTextEditorFocused: Bool

    // 长按阈值（秒）- 超过这个时间算长按（语音），否则算短按（文字）
    private let longPressThreshold: TimeInterval = 0.3

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView

            // 内容区域
            ScrollView {
                VStack(spacing: 20) {
                    // 频道选择区域
                    channelSelectionSection

                    // 已选频道信息卡片
                    if let channel = selectedChannel {
                        selectedChannelCard(channel.channel)
                    }

                    // 呼叫内容输入区域
                    callContentInputSection

                    // PTT 按钮区域
                    pttButtonSection
                }
                .padding()
            }
            .onTapGesture {
                isTextEditorFocused = false
            }
        }
        .background(ApocalypseTheme.background)
        .task {
            if let userId = authManager.currentUser?.id {
                await communicationManager.loadSubscribedChannels(userId: userId)
            }
        }
    }

    // MARK: - 标题栏

    private var headerView: some View {
        HStack {
            Text("PTT 呼叫")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            Spacer()

            // 设备范围指示
            if let device = communicationManager.currentDevice {
                HStack(spacing: 4) {
                    Text(device.deviceType.rangeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(ApocalypseTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ApocalypseTheme.primary.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ApocalypseTheme.surface)
    }

    // MARK: - 频道选择

    private var channelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if communicationManager.subscribedChannels.isEmpty {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                    Text("暂无订阅频道")
                        .foregroundColor(ApocalypseTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(communicationManager.subscribedChannels) { subscribedChannel in
                            ChannelChip(
                                channel: subscribedChannel.channel,
                                isSelected: selectedChannel?.id == subscribedChannel.id
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedChannel?.id == subscribedChannel.id {
                                        selectedChannel = nil
                                    } else {
                                        selectedChannel = subscribedChannel
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 已选频道卡片

    private func selectedChannelCard(_ channel: CommunicationChannel) -> some View {
        VStack(spacing: 12) {
            HStack {
                // 频道图标
                Image(systemName: channel.channelType.iconName)
                    .font(.title2)
                    .foregroundColor(ApocalypseTheme.primary)

                Spacer()

                // 设备范围和状态
                HStack(spacing: 4) {
                    Text(communicationManager.currentDevice?.deviceType.rangeText ?? "")
                        .font(.caption)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.success)
                }
                .foregroundColor(ApocalypseTheme.primary)
            }

            // 频道代码
            Text(channel.channelCode)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 频道名称
            Text(channel.name)
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - 呼叫内容输入区域

    private var callContentInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("呼叫内容")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)

            TextEditor(text: $messageText)
                .frame(minHeight: 100, maxHeight: 150)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
                .focused($isTextEditorFocused)
                .overlay(
                    Group {
                        if messageText.isEmpty {
                            Text("输入您的呼叫内容，然后按住PTT按钮发送")
                                .font(.body)
                                .foregroundColor(Color.gray.opacity(0.6))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ApocalypseTheme.primary.opacity(0.5), lineWidth: 2)
        )
    }

    // MARK: - PTT 按钮区域

    private var pttButtonSection: some View {
        VStack(spacing: 16) {
            // PTT 按钮
            ZStack {
                // 外圈动画
                Circle()
                    .stroke(ApocalypseTheme.primary.opacity(isPressing ? 0.5 : 0.2), lineWidth: 4)
                    .frame(width: 160, height: 160)
                    .scaleEffect(isPressing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isPressing)

                // 主按钮
                Circle()
                    .fill(
                        canSendMessage
                            ? (isPressing ? ApocalypseTheme.primary : ApocalypseTheme.primary.opacity(0.8))
                            : ApocalypseTheme.textSecondary.opacity(0.5)
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: isPressing ? ApocalypseTheme.primary.opacity(0.5) : .clear, radius: 20)

                // 图标和文字
                VStack(spacing: 8) {
                    Image(systemName: isPressing ? "waveform" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor, isActive: isPressing)

                    Text(isPressing ? "松开发送" : "按住发送")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if canSendMessage && !isPressing {
                            startPressing()
                        }
                    }
                    .onEnded { _ in
                        if isPressing {
                            stopPressing()
                        }
                    }
            )
            .disabled(!canSendMessage)

            // 状态提示
            if !canSendMessage {
                Text(disabledReason)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.warning)
                    .multilineTextAlignment(.center)
            } else {
                Text("短按发送文字 · 长按发送语音(开发中)")
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.textSecondary)
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - 计算属性

    private var canSendMessage: Bool {
        guard communicationManager.currentDevice?.deviceType.canSend == true else { return false }
        guard selectedChannel != nil else { return false }
        return true
    }

    private var disabledReason: String {
        if communicationManager.currentDevice?.deviceType.canSend != true {
            return "当前设备不支持发送消息\n请切换到对讲机或更高级设备"
        }
        if selectedChannel == nil {
            return "请先选择一个频道"
        }
        return ""
    }

    // MARK: - 方法

    private func startPressing() {
        isPressing = true
        pressStartTime = Date()
        // 收起键盘
        isTextEditorFocused = false
        // 触觉反馈
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    private func stopPressing() {
        isPressing = false
        // 触觉反馈
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // 计算按压时长
        guard let startTime = pressStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        pressStartTime = nil

        if duration < longPressThreshold {
            // 短按 -> 发送文字消息
            Task {
                await sendTextMessage()
            }
        } else {
            // 长按 -> 语音功能（开发中）
            print("PTT 长按 \(String(format: "%.1f", duration))秒 - 语音功能开发中")
        }
    }

    private func sendTextMessage() async {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            // 没有输入内容时给出提示
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.warning)
            return
        }

        guard let channel = selectedChannel else { return }

        isSending = true

        let deviceType = communicationManager.getCurrentDeviceType().rawValue
        let location = LocationManager.shared.userLocation

        let success = await communicationManager.sendChannelMessage(
            channelId: channel.channel.id,
            content: content,
            latitude: location?.latitude,
            longitude: location?.longitude,
            deviceType: deviceType
        )

        isSending = false

        if success {
            // 发送成功，清空输入框
            messageText = ""
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.success)
        } else {
            let notification = UINotificationFeedbackGenerator()
            notification.notificationOccurred(.error)
        }
    }
}

// MARK: - 频道选择芯片

struct ChannelChip: View {
    let channel: CommunicationChannel
    let isSelected: Bool

    private var isOfficial: Bool {
        channel.id == CommunicationManager.officialChannelId
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: channel.channelType.iconName)
                .font(.system(size: 14))
            Text(channel.name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(isSelected ? .white : channelColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? channelColor : channelColor.opacity(0.15))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? channelColor : Color.clear, lineWidth: 2)
        )
    }

    private var channelColor: Color {
        switch channel.channelType {
        case .official: return ApocalypseTheme.warning
        case .publicChannel: return ApocalypseTheme.primary
        case .walkie: return ApocalypseTheme.success
        case .camp: return ApocalypseTheme.secondary
        case .satellite: return ApocalypseTheme.info
        }
    }
}

#Preview {
    PTTCallView()
        .environmentObject(AuthManager())
}
