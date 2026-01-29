//
//  TradeHistoryView.swift
//  EarthLord day7
//
//  交易历史页面
//  显示用户的所有交易历史记录
//

import SwiftUI

/// 交易历史视图
struct TradeHistoryView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    @ObservedObject var tradeManager: TradeManager

    /// 当前用户ID
    let currentUserId: UUID?

    /// 选中要评分的历史记录
    @State private var selectedHistoryForRating: DBTradeHistory? = nil

    /// 错误信息
    @State private var errorMessage: String? = nil

    // MARK: - 视图

    var body: some View {
        VStack(spacing: 0) {
            // 历史记录列表
            historyList
        }
        .background(ApocalypseTheme.background)
        .sheet(item: $selectedHistoryForRating, onDismiss: {
            // 评分完成后刷新历史列表
            Task {
                await tradeManager.loadHistory()
            }
        }) { history in
            if let userId = currentUserId {
                RatingView(
                    history: history,
                    currentUserId: userId
                )
                .environmentObject(languageManager)
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

    // MARK: - 历史列表

    private var historyList: some View {
        ScrollView {
            if tradeManager.isLoading && tradeManager.myHistory.isEmpty {
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 60)
            } else if tradeManager.myHistory.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    // 待评价提示
                    if let userId = currentUserId {
                        let pendingCount = tradeManager.pendingRatingCount(userId: userId)
                        if pendingCount > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(ApocalypseTheme.warning)

                                Text(String(format: languageManager.localizedString("trade_pending_rating_count"), pendingCount))
                                    .font(.system(size: 13))
                                    .foregroundColor(ApocalypseTheme.textSecondary)

                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(ApocalypseTheme.warning.opacity(0.1))
                            )
                        }
                    }

                    ForEach(tradeManager.myHistory) { history in
                        if let userId = currentUserId {
                            TradeHistoryCard(
                                history: history,
                                currentUserId: userId,
                                onRate: {
                                    selectedHistoryForRating = history
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .refreshable {
            await tradeManager.loadHistory()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(ApocalypseTheme.textMuted)

            Text(languageManager.localizedString("trade_empty_history"))
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(languageManager.localizedString("trade_empty_history_hint"))
                .font(.system(size: 14))
                .foregroundColor(ApocalypseTheme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

}

// MARK: - 预览

#Preview {
    TradeHistoryView(
        tradeManager: TradeManager.shared,
        currentUserId: UUID()
    )
    .environmentObject(LanguageManager.shared)
}
