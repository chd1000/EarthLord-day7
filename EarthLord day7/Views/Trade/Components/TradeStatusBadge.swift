//
//  TradeStatusBadge.swift
//  EarthLord day7
//
//  交易状态标签组件
//

import SwiftUI

/// 交易状态标签
struct TradeStatusBadge: View {
    let status: TradeStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))

            Text(status.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.15))
        )
    }

    private var statusColor: Color {
        switch status {
        case .active: return ApocalypseTheme.info
        case .completed: return ApocalypseTheme.success
        case .cancelled: return ApocalypseTheme.textMuted
        case .expired: return ApocalypseTheme.warning
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        TradeStatusBadge(status: .active)
        TradeStatusBadge(status: .completed)
        TradeStatusBadge(status: .cancelled)
        TradeStatusBadge(status: .expired)
    }
    .padding()
    .background(ApocalypseTheme.background)
}
