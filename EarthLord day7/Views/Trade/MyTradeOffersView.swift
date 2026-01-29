//
//  MyTradeOffersView.swift
//  EarthLord day7
//
//  我的挂单页面
//  显示用户自己发布的所有挂单
//

import SwiftUI

/// 我的挂单视图
struct MyTradeOffersView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    @ObservedObject var tradeManager: TradeManager

    /// 当前用户ID
    let currentUserId: UUID?

    /// 状态筛选
    @State private var selectedStatus: TradeStatus? = nil

    /// 选中的挂单（用于详情页）
    @State private var selectedOffer: DBTradeOffer? = nil

    /// 取消确认
    @State private var offerToCancel: DBTradeOffer? = nil

    /// 是否正在取消
    @State private var isCancelling: Bool = false

    /// 错误信息
    @State private var errorMessage: String? = nil

    // MARK: - 计算属性

    /// 筛选后的我的挂单
    private var filteredOffers: [DBTradeOffer] {
        var result = tradeManager.myOffers

        if let status = selectedStatus {
            result = result.filter { $0.statusEnum == status }
        }

        return result
    }

    /// 各状态数量
    private var statusCounts: [TradeStatus: Int] {
        var counts: [TradeStatus: Int] = [:]
        for status in TradeStatus.allCases {
            counts[status] = tradeManager.myOffers.filter { $0.statusEnum == status }.count
        }
        return counts
    }

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 状态筛选
            statusFilter
                .padding(.top, 12)

            // 挂单列表
            offerList
                .padding(.top, 12)
        }
        .background(ApocalypseTheme.background)
        .sheet(item: $selectedOffer) { offer in
            TradeOfferDetailView(
                offer: offer,
                currentUserId: currentUserId,
                onAccept: nil
            )
            .environmentObject(languageManager)
        }
        .confirmationDialog(
            languageManager.localizedString("trade_confirm_cancel"),
            isPresented: Binding(
                get: { offerToCancel != nil },
                set: { if !$0 { offerToCancel = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(languageManager.localizedString("trade_btn_cancel"), role: .destructive) {
                if let offer = offerToCancel {
                    Task {
                        await cancelOffer(offer)
                    }
                }
            }
            Button(languageManager.localizedString("取消"), role: .cancel) {
                offerToCancel = nil
            }
        } message: {
            Text(languageManager.localizedString("trade_cancel_warning"))
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
    }

    // MARK: - 状态筛选

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 全部
                StatusFilterChip(
                    title: languageManager.localizedString("全部"),
                    count: tradeManager.myOffers.count,
                    color: ApocalypseTheme.primary,
                    isSelected: selectedStatus == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = nil
                    }
                }

                // 等待中
                StatusFilterChip(
                    title: TradeStatus.active.displayName,
                    count: statusCounts[.active] ?? 0,
                    color: ApocalypseTheme.info,
                    isSelected: selectedStatus == .active
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = .active
                    }
                }

                // 已完成
                StatusFilterChip(
                    title: TradeStatus.completed.displayName,
                    count: statusCounts[.completed] ?? 0,
                    color: ApocalypseTheme.success,
                    isSelected: selectedStatus == .completed
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = .completed
                    }
                }

                // 已取消
                StatusFilterChip(
                    title: TradeStatus.cancelled.displayName,
                    count: statusCounts[.cancelled] ?? 0,
                    color: ApocalypseTheme.textMuted,
                    isSelected: selectedStatus == .cancelled
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = .cancelled
                    }
                }

                // 已过期
                StatusFilterChip(
                    title: TradeStatus.expired.displayName,
                    count: statusCounts[.expired] ?? 0,
                    color: ApocalypseTheme.warning,
                    isSelected: selectedStatus == .expired
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedStatus = .expired
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 挂单列表

    private var offerList: some View {
        ScrollView {
            if tradeManager.isLoading && filteredOffers.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 60)
            } else if filteredOffers.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredOffers) { offer in
                        TradeOfferCard(
                            offer: offer,
                            isOwner: true,
                            onCancel: {
                                offerToCancel = offer
                            },
                            onTap: {
                                selectedOffer = offer
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .refreshable {
            await tradeManager.loadMyOffers()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(languageManager.localizedString("trade_empty_my_offers"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(languageManager.localizedString("trade_empty_my_offers_hint"))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    // MARK: - 取消挂单

    private func cancelOffer(_ offer: DBTradeOffer) async {
        isCancelling = true
        do {
            try await tradeManager.cancelOffer(offerId: offer.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isCancelling = false
        offerToCancel = nil
    }
}

// MARK: - 状态筛选按钮

struct StatusFilterChip: View {
    let title: String
    let count: Int
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? color : ApocalypseTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.2) : ApocalypseTheme.cardBackground)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : ApocalypseTheme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color : ApocalypseTheme.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : ApocalypseTheme.textMuted.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - 预览

#Preview {
    MyTradeOffersView(
        tradeManager: TradeManager.shared,
        currentUserId: UUID()
    )
    .environmentObject(LanguageManager.shared)
}
