//
//  CommunicationManager.swift
//  EarthLord day7
//
//  通讯系统管理器
//

import Foundation
import Combine
import Supabase
import Realtime
import CoreLocation

@MainActor
final class CommunicationManager: ObservableObject {
    static let shared = CommunicationManager()

    @Published private(set) var devices: [CommunicationDevice] = []
    @Published private(set) var currentDevice: CommunicationDevice?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // 频道相关
    @Published private(set) var channels: [CommunicationChannel] = []
    @Published private(set) var subscribedChannels: [SubscribedChannel] = []
    @Published private(set) var mySubscriptions: [ChannelSubscription] = []

    // MARK: - 消息相关属性
    @Published var channelMessages: [UUID: [ChannelMessage]] = [:]
    @Published var isSendingMessage = false

    // MARK: - Realtime 相关属性
    private var realtimeChannel: RealtimeChannelV2?
    private var messageSubscriptionTask: Task<Void, Never>?
    @Published var subscribedChannelIds: Set<UUID> = []

    private let client = supabase

    private init() {}

    // MARK: - 加载设备

    func loadDevices(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationDevice] = try await client
                .from("communication_devices")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            devices = response
            currentDevice = devices.first(where: { $0.isCurrent })

            if devices.isEmpty {
                await initializeDevices(userId: userId)
            }
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 初始化设备

    func initializeDevices(userId: UUID) async {
        do {
            try await client.rpc("initialize_user_devices", params: ["p_user_id": userId.uuidString]).execute()
            await loadDevices(userId: userId)
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 切换设备

    func switchDevice(userId: UUID, to deviceType: DeviceType) async {
        guard let device = devices.first(where: { $0.deviceType == deviceType }), device.isUnlocked else {
            errorMessage = "设备未解锁"
            return
        }

        if device.isCurrent { return }

        isLoading = true

        do {
            try await client.rpc("switch_current_device", params: [
                "p_user_id": userId.uuidString,
                "p_device_type": deviceType.rawValue
            ]).execute()

            for i in devices.indices {
                devices[i].isCurrent = (devices[i].deviceType == deviceType)
            }
            currentDevice = devices.first(where: { $0.deviceType == deviceType })
        } catch {
            errorMessage = "切换失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 解锁设备（由建造系统调用）

    func unlockDevice(userId: UUID, deviceType: DeviceType) async {
        do {
            let updateData = DeviceUnlockUpdate(
                isUnlocked: true,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("communication_devices")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .eq("device_type", value: deviceType.rawValue)
                .execute()

            if let index = devices.firstIndex(where: { $0.deviceType == deviceType }) {
                devices[index].isUnlocked = true
            }
        } catch {
            errorMessage = "解锁失败: \(error.localizedDescription)"
        }
    }

    // MARK: - 辅助方法

    func getCurrentDeviceType() -> DeviceType {
        currentDevice?.deviceType ?? .walkieTalkie
    }

    func canSendMessage() -> Bool {
        currentDevice?.deviceType.canSend ?? false
    }

    func getCurrentRange() -> Double {
        currentDevice?.deviceType.range ?? 3.0
    }

    func isDeviceUnlocked(_ deviceType: DeviceType) -> Bool {
        devices.first(where: { $0.deviceType == deviceType })?.isUnlocked ?? false
    }

    // MARK: - 频道方法

    /// 加载所有公开频道
    func loadPublicChannels() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value

            channels = response
        } catch {
            errorMessage = "加载频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 加载用户订阅的频道
    func loadSubscribedChannels(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            // 先加载订阅
            let subscriptions: [ChannelSubscription] = try await client
                .from("channel_subscriptions")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            mySubscriptions = subscriptions

            if subscriptions.isEmpty {
                subscribedChannels = []
                isLoading = false
                return
            }

            // 获取订阅频道的ID列表
            let channelIds = subscriptions.map { $0.channelId.uuidString }

            // 加载对应的频道信息
            let channelsData: [CommunicationChannel] = try await client
                .from("communication_channels")
                .select()
                .in("id", values: channelIds)
                .execute()
                .value

            // 组合成 SubscribedChannel
            subscribedChannels = subscriptions.compactMap { sub in
                guard let channel = channelsData.first(where: { $0.id == sub.channelId }) else {
                    return nil
                }
                return SubscribedChannel(channel: channel, subscription: sub)
            }
        } catch {
            errorMessage = "加载订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 创建频道
    func createChannel(userId: UUID, type: ChannelType, name: String, description: String?) async {
        isLoading = true
        errorMessage = nil

        do {
            var params: [String: String] = [
                "p_creator_id": userId.uuidString,
                "p_channel_type": type.rawValue,
                "p_name": name
            ]
            if let desc = description {
                params["p_description"] = desc
            }

            try await client.rpc("create_channel_with_subscription", params: params).execute()

            // 重新加载频道列表
            await loadPublicChannels()
            await loadSubscribedChannels(userId: userId)
        } catch {
            errorMessage = "创建频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 订阅频道
    func subscribeToChannel(userId: UUID, channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            try await client.rpc("subscribe_to_channel", params: [
                "p_user_id": userId.uuidString,
                "p_channel_id": channelId.uuidString
            ]).execute()

            // 重新加载订阅列表
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()
        } catch {
            errorMessage = "订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 取消订阅
    func unsubscribeFromChannel(userId: UUID, channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            try await client.rpc("unsubscribe_from_channel", params: [
                "p_user_id": userId.uuidString,
                "p_channel_id": channelId.uuidString
            ]).execute()

            // 重新加载订阅列表
            await loadSubscribedChannels(userId: userId)
            await loadPublicChannels()
        } catch {
            errorMessage = "取消订阅失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 删除频道
    func deleteChannel(channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            try await client
                .from("communication_channels")
                .delete()
                .eq("id", value: channelId.uuidString)
                .execute()

            // 从本地列表移除
            channels.removeAll { $0.id == channelId }
            subscribedChannels.removeAll { $0.channel.id == channelId }
        } catch {
            errorMessage = "删除频道失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 检查是否已订阅
    func isSubscribed(channelId: UUID) -> Bool {
        mySubscriptions.contains { $0.channelId == channelId }
    }

    // MARK: - 消息方法

    /// 加载频道消息
    func loadChannelMessages(channelId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: [ChannelMessage] = try await client
                .from("channel_messages")
                .select()
                .eq("channel_id", value: channelId.uuidString)
                .order("created_at", ascending: true)
                .limit(100)
                .execute()
                .value

            channelMessages[channelId] = response
        } catch {
            errorMessage = "加载消息失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 发送频道消息
    func sendChannelMessage(channelId: UUID, content: String, latitude: Double?, longitude: Double?, deviceType: String?) async -> Bool {
        isSendingMessage = true
        errorMessage = nil

        do {
            var params: [String: AnyJSON] = [
                "p_channel_id": .string(channelId.uuidString),
                "p_content": .string(content)
            ]

            if let lat = latitude {
                params["p_latitude"] = .double(lat)
            }
            if let lon = longitude {
                params["p_longitude"] = .double(lon)
            }
            if let device = deviceType {
                params["p_device_type"] = .string(device)
            }

            try await client.rpc("send_channel_message", params: params).execute()

            isSendingMessage = false
            return true
        } catch {
            errorMessage = "发送失败: \(error.localizedDescription)"
            isSendingMessage = false
            return false
        }
    }

    /// 获取频道消息
    func getMessages(for channelId: UUID) -> [ChannelMessage] {
        channelMessages[channelId] ?? []
    }

    // MARK: - Realtime 订阅

    /// 启动 Realtime 订阅
    func startRealtimeSubscription() async {
        guard realtimeChannel == nil else { return }

        let channel = client.realtimeV2.channel("channel_messages_changes")

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "channel_messages"
        )

        messageSubscriptionTask = Task {
            for await insertion in insertions {
                await handleNewMessage(insertion: insertion)
            }
        }

        realtimeChannel = channel
        do {
            try await channel.subscribeWithError()
        } catch {
            print("Realtime 订阅失败: \(error)")
        }
    }

    /// 停止 Realtime 订阅
    func stopRealtimeSubscription() async {
        messageSubscriptionTask?.cancel()
        messageSubscriptionTask = nil

        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
        }
    }

    /// 处理新消息
    private func handleNewMessage(insertion: InsertAction) async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let message = try insertion.decodeRecord(as: ChannelMessage.self, decoder: decoder)

            // 第一关：检查是否是已订阅频道的消息
            guard subscribedChannelIds.contains(message.channelId) else {
                return
            }

            // 第二关：距离过滤（Day 35 新增）
            guard shouldReceiveMessage(message) else {
                return
            }

            // 添加到消息列表（防止重复）
            if channelMessages[message.channelId] != nil {
                if !channelMessages[message.channelId]!.contains(where: { $0.id == message.id }) {
                    channelMessages[message.channelId]?.append(message)
                }
            } else {
                channelMessages[message.channelId] = [message]
            }
        } catch {
            print("解码消息失败: \(error)")
        }
    }

    /// 订阅频道消息（UI层调用）
    func subscribeToChannelMessages(channelId: UUID) {
        subscribedChannelIds.insert(channelId)
    }

    /// 取消订阅频道消息（UI层调用）
    func unsubscribeFromChannelMessages(channelId: UUID) {
        subscribedChannelIds.remove(channelId)
    }
    // MARK: - 距离过滤逻辑

    /// 判断是否应该接收该消息
    func shouldReceiveMessage(_ message: ChannelMessage, channel: CommunicationChannel? = nil) -> Bool {
        // 1. 私有频道不过滤（只对公共频道应用距离过滤）
        if let channel = channel, channel.channelType != .publicChannel {
            return true
        }

        // 2. 获取当前用户设备类型
        guard let myDeviceType = currentDevice?.deviceType else {
            print("⚠️ [距离过滤] 无法获取当前设备，保守显示消息")
            return true  // 保守策略
        }

        // 3. 收音机可以接收所有消息
        if myDeviceType == .radio {
            print("📻 [距离过滤] 收音机用户，接收所有消息")
            return true
        }

        // 4. 检查发送者设备类型
        guard let senderDevice = message.senderDeviceType else {
            print("⚠️ [距离过滤] 消息缺少设备类型，保守显示")
            return true  // 向后兼容老消息
        }

        // 5. 收音机不能发送消息
        if senderDevice == .radio {
            print("🚫 [距离过滤] 收音机不能发送消息")
            return false
        }

        // 6. 检查发送者位置
        guard let senderLocation = message.senderLocation else {
            print("⚠️ [距离过滤] 消息缺少位置信息，保守显示")
            return true  // 保守策略
        }

        // 7. 获取当前用户位置
        guard let myLocation = getCurrentLocation() else {
            print("⚠️ [距离过滤] 无法获取当前位置，保守显示")
            return true  // 保守策略
        }

        // 8. 计算距离
        let distance = calculateDistance(
            from: CLLocationCoordinate2D(latitude: myLocation.latitude, longitude: myLocation.longitude),
            to: CLLocationCoordinate2D(latitude: senderLocation.latitude, longitude: senderLocation.longitude)
        )

        // 9. 设备矩阵判断
        let canReceive = canReceiveMessage(senderDevice: senderDevice, myDevice: myDeviceType, distance: distance)

        if canReceive {
            print("✅ [距离过滤] 通过: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        } else {
            print("🚫 [距离过滤] 丢弃: 发送者=\(senderDevice.rawValue), 我=\(myDeviceType.rawValue), 距离=\(String(format: "%.1f", distance))km")
        }

        return canReceive
    }

    /// 设备矩阵判断
    private func canReceiveMessage(senderDevice: DeviceType, myDevice: DeviceType, distance: Double) -> Bool {
        if myDevice == .radio { return true }
        if senderDevice == .radio { return false }

        switch (senderDevice, myDevice) {
        case (.walkieTalkie, .walkieTalkie): return distance <= 3.0
        case (.walkieTalkie, .campRadio): return distance <= 30.0
        case (.walkieTalkie, .satellite): return distance <= 100.0
        case (.campRadio, .walkieTalkie): return distance <= 30.0
        case (.campRadio, .campRadio): return distance <= 30.0
        case (.campRadio, .satellite): return distance <= 100.0
        case (.satellite, .walkieTalkie): return distance <= 100.0
        case (.satellite, .campRadio): return distance <= 100.0
        case (.satellite, .satellite): return distance <= 100.0
        default: return false
        }
    }

    /// 计算两点距离（公里）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc) / 1000.0
    }

    /// 获取当前用户位置
    private func getCurrentLocation() -> LocationPoint? {
        // Day 35-B: 从 LocationManager 获取真实位置
        guard let coordinate = LocationManager.shared.userLocation else {
            print("⚠️ [距离过滤] LocationManager 无位置数据")
            return nil
        }
        return LocationPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

// MARK: - Update Models

private struct DeviceUnlockUpdate: Encodable {
    let isUnlocked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isUnlocked = "is_unlocked"
        case updatedAt = "updated_at"
    }
}
