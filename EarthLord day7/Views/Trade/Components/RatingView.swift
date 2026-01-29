//
//  RatingView.swift
//  EarthLord day7
//
//  评分组件
//  显示交易摘要和5星评分选择
//

import SwiftUI

/// 评分视图
struct RatingView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let history: DBTradeHistory
    let currentUserId: UUID

    @StateObject private var tradeManager = TradeManager.shared

    @State private var selectedRating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    /// 当前用户是否是卖家
    private var isSeller: Bool {
        history.sellerId == currentUserId
    }

    /// 我给出的物品（安全访问）
    private var itemsGiven: [TradeItem] {
        let items = isSeller ? history.itemsExchanged.sellerItems : history.itemsExchanged.buyerItems
        return items
    }

    /// 我获得的物品（安全访问）
    private var itemsReceived: [TradeItem] {
        let items = isSeller ? history.itemsExchanged.buyerItems : history.itemsExchanged.sellerItems
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        // 交易摘要
                        VStack(spacing: 16) {
                            Text(languageManager.localizedString("trade_rating_summary"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textSecondary)

                            HStack(spacing: 12) {
                                // 给出的物品
                                VStack(spacing: 6) {
                                    Text(languageManager.localizedString("trade_given"))
                                        .font(.system(size: 11))
                                        .foregroundColor(ApocalypseTheme.textMuted)

                                    VStack(spacing: 4) {
                                        ForEach(itemsGiven) { item in
                                            TradeItemMiniCard(item: item)
                                        }
                                    }
                                }

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16))
                                    .foregroundColor(ApocalypseTheme.textMuted)

                                // 获得的物品
                                VStack(spacing: 6) {
                                    Text(languageManager.localizedString("trade_received"))
                                        .font(.system(size: 11))
                                        .foregroundColor(ApocalypseTheme.textMuted)

                                    VStack(spacing: 4) {
                                        ForEach(itemsReceived) { item in
                                            TradeItemMiniCard(item: item)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ApocalypseTheme.cardBackground)
                        )

                        // 评分选择
                        VStack(spacing: 12) {
                            Text(languageManager.localizedString("trade_rating_prompt"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(ApocalypseTheme.textPrimary)

                            // 星星
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedRating = star
                                        }
                                    } label: {
                                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                            .font(.system(size: 36))
                                            .foregroundColor(star <= selectedRating ? .yellow : ApocalypseTheme.textMuted)
                                            .scaleEffect(star <= selectedRating ? 1.1 : 1.0)
                                    }
                                }
                            }

                            // 评分描述
                            if selectedRating > 0 {
                                Text(ratingDescription)
                                    .font(.system(size: 13))
                                    .foregroundColor(ApocalypseTheme.textSecondary)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 20)

                        // 评语输入
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(languageManager.localizedString("trade_comment_label"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(ApocalypseTheme.textPrimary)

                                Text(languageManager.localizedString("trade_optional"))
                                    .font(.system(size: 11))
                                    .foregroundColor(ApocalypseTheme.textMuted)
                            }

                            TextField(languageManager.localizedString("trade_comment_placeholder"), text: $comment, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundColor(ApocalypseTheme.textPrimary)
                                .lineLimit(2...4)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(ApocalypseTheme.cardBackground)
                                )
                        }

                        // 提交按钮
                        Button {
                            submitRating()
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                }
                                Text(languageManager.localizedString("trade_btn_submit_rating"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedRating > 0 ? ApocalypseTheme.primary : ApocalypseTheme.textMuted)
                            )
                        }
                        .disabled(selectedRating == 0 || isSubmitting)
                        .id("submitButton")
                        .padding(.bottom, 20)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: comment) { _, _ in
                    // 输入评语时自动滚动到提交按钮
                    withAnimation {
                        proxy.scrollTo("submitButton", anchor: .bottom)
                    }
                }
            }
            .background(ApocalypseTheme.background)
            .navigationTitle(languageManager.localizedString("trade_rating_title"))
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
    }

    // MARK: - 提交评分

    private func submitRating() {
        isSubmitting = true
        Task { @MainActor in
            do {
                try await tradeManager.rateTradeHistory(
                    historyId: history.id,
                    rating: selectedRating,
                    comment: comment.isEmpty ? nil : comment
                )
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// 评分描述
    private var ratingDescription: String {
        switch selectedRating {
        case 1: return languageManager.localizedString("trade_rating_1")
        case 2: return languageManager.localizedString("trade_rating_2")
        case 3: return languageManager.localizedString("trade_rating_3")
        case 4: return languageManager.localizedString("trade_rating_4")
        case 5: return languageManager.localizedString("trade_rating_5")
        default: return ""
        }
    }
}

// MARK: - 预览

#Preview {
    let userId = UUID()

    return RatingView(
        history: DBTradeHistory(
            id: UUID(),
            offerId: UUID(),
            sellerId: userId,
            buyerId: UUID(),
            itemsExchanged: ItemsExchanged(
                sellerItems: [
                    TradeItem(itemId: UUID(), itemType: "normal", itemName: "急救包", quantity: 5, category: "medical", rarity: "rare", icon: "cross.case.fill")
                ],
                buyerItems: [
                    TradeItem(itemId: UUID(), itemType: "normal", itemName: "钢铁", quantity: 20, category: "material", rarity: "uncommon", icon: "cube.fill")
                ]
            ),
            completedAt: Date(),
            sellerRating: nil,
            buyerRating: nil
        ),
        currentUserId: userId
    )
    .environmentObject(LanguageManager.shared)
}
