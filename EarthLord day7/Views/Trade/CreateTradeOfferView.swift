//
//  CreateTradeOfferView.swift
//  EarthLord day7
//
//  发布挂单页面
//  允许用户选择要出的物品和想要的物品，设置有效期
//

import SwiftUI

/// 发布挂单视图
struct CreateTradeOfferView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var tradeManager: TradeManager

    /// 提供的物品列表
    @State private var offeringItems: [TradeItem] = []

    /// 请求的物品列表
    @State private var requestingItems: [TradeItem] = []

    /// 有效期（小时）
    @State private var expiresHours: Int = 24

    /// 留言（可选）
    @State private var message: String = ""

    /// 显示物品选择器（提供）
    @State private var showOfferingPicker: Bool = false

    /// 显示物品选择器（请求）
    @State private var showRequestingPicker: Bool = false

    /// 是否正在创建
    @State private var isCreating: Bool = false

    /// 错误信息
    @State private var errorMessage: String? = nil

    /// 创建成功
    @State private var createSuccess: Bool = false

    /// 有效期选项
    private let expiresOptions: [(hours: Int, label: String)] = [
        (6, "6小时"),
        (12, "12小时"),
        (24, "24小时"),
        (48, "48小时"),
        (72, "72小时")
    ]

    /// 是否可以发布
    private var canPublish: Bool {
        !offeringItems.isEmpty && !isCreating
    }

    /// 已选择物品的ID集合（用于排除）
    private var selectedItemIds: Set<UUID> {
        Set(offeringItems.map { $0.itemId })
    }

    // MARK: - 视图

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 提供物品区域
                    offeringSection

                    // 请求物品区域
                    requestingSection

                    // 留言区域
                    messageSection

                    // 有效期选择
                    expiresSection

                    // 发布按钮
                    publishButton
                }
                .padding(16)
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(languageManager.localizedString("trade_create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(ApocalypseTheme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showOfferingPicker) {
                ItemPickerView(
                    isRequestMode: false,
                    excludedItemIds: selectedItemIds,
                    onSelect: { items in
                        offeringItems.append(contentsOf: items)
                    }
                )
                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showRequestingPicker) {
                ItemPickerView(
                    isRequestMode: true,
                    excludedItemIds: Set(requestingItems.map { $0.itemId }),
                    onSelect: { items in
                        requestingItems.append(contentsOf: items)
                    }
                )
                .environmentObject(languageManager)
            }
            .alert(languageManager.localizedString("错误"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(languageManager.localizedString("确定"), role: .cancel) {}
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert(languageManager.localizedString("trade_create_success"), isPresented: $createSuccess) {
                Button(languageManager.localizedString("确定"), role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(languageManager.localizedString("trade_create_success_msg"))
            }
        }
    }

    // MARK: - 提供物品区域

    private var offeringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.primary)

                Text(languageManager.localizedString("trade_section_offering"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text("*")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(ApocalypseTheme.danger)

                Spacer()

                // 添加按钮
                Button {
                    showOfferingPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(languageManager.localizedString("trade_btn_add"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.primary.opacity(0.15))
                    )
                }
            }

            // 物品列表
            if offeringItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundColor(ApocalypseTheme.textMuted)

                        Text(languageManager.localizedString("trade_no_offering"))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textMuted)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(offeringItems) { item in
                    TradeItemCard(
                        item: item,
                        showDeleteButton: true,
                        onDelete: {
                            withAnimation {
                                offeringItems.removeAll { $0.id == item.id }
                            }
                        }
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 请求物品区域

    private var requestingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.success)

                Text(languageManager.localizedString("trade_section_requesting"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(languageManager.localizedString("trade_optional"))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.textMuted.opacity(0.2))
                    )

                Spacer()

                // 添加按钮
                Button {
                    showRequestingPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(languageManager.localizedString("trade_btn_add"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(ApocalypseTheme.success)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.success.opacity(0.15))
                    )
                }
            }

            // 提示
            if requestingItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "gift")
                            .font(.system(size: 28))
                            .foregroundColor(ApocalypseTheme.success.opacity(0.5))

                        Text(languageManager.localizedString("trade_open_offer_hint"))
                            .font(.system(size: 13))
                            .foregroundColor(ApocalypseTheme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(requestingItems) { item in
                    TradeItemCard(
                        item: item,
                        showDeleteButton: true,
                        onDelete: {
                            withAnimation {
                                requestingItems.removeAll { $0.id == item.id }
                            }
                        }
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 留言区域

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.info)

                Text(languageManager.localizedString("trade_section_message"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)

                Text(languageManager.localizedString("trade_optional"))
                    .font(.system(size: 12))
                    .foregroundColor(ApocalypseTheme.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(ApocalypseTheme.textMuted.opacity(0.2))
                    )
            }

            TextField(languageManager.localizedString("trade_message_placeholder"), text: $message, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textPrimary)
                .lineLimit(3...5)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ApocalypseTheme.background)
                )

            Text(languageManager.localizedString("trade_message_hint"))
                .font(.system(size: 12))
                .foregroundColor(ApocalypseTheme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 有效期区域

    private var expiresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ApocalypseTheme.info)

                Text(languageManager.localizedString("trade_section_expires"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ApocalypseTheme.textPrimary)
            }

            // 有效期选项
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(expiresOptions, id: \.hours) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expiresHours = option.hours
                            }
                        } label: {
                            Text(option.label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(expiresHours == option.hours ? .white : ApocalypseTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(expiresHours == option.hours ? ApocalypseTheme.info : ApocalypseTheme.background)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(expiresHours == option.hours ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)
        )
    }

    // MARK: - 发布按钮

    private var publishButton: some View {
        Button {
            Task {
                await createOffer()
            }
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                }
                Text(languageManager.localizedString("trade_btn_publish"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canPublish ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
            )
        }
        .disabled(!canPublish)
    }

    // MARK: - 创建挂单

    private func createOffer() async {
        isCreating = true
        do {
            _ = try await tradeManager.createOffer(
                offeringItems: offeringItems,
                requestingItems: requestingItems.isEmpty ? nil : requestingItems,
                expiresHours: expiresHours,
                message: message.isEmpty ? nil : message
            )
            createSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}

// MARK: - 预览

#Preview {
    CreateTradeOfferView(tradeManager: TradeManager.shared)
        .environmentObject(LanguageManager.shared)
}
