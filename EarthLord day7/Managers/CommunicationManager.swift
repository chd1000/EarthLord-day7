//
//  CommunicationManager.swift
//  EarthLord day7
//
//  通讯系统管理器
//

import Foundation
import Combine
import Supabase

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
