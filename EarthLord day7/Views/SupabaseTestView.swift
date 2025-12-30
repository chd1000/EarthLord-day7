//
//  SupabaseTestView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/24.
//

import SwiftUI
import Supabase

// MARK: - Supabase 客户端初始化
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://bgjosiapfuiuyuczxhgp.supabase.co")!,
    supabaseKey: "sb_publishable_nkHYaKHIdAnO8F_OiqhLUA_pHf0P_0M"
)

// MARK: - Supabase 测试视图
struct SupabaseTestView: View {
    /// 连接状态：nil=未测试, true=成功, false=失败
    @State private var connectionStatus: Bool? = nil

    /// 调试日志
    @State private var debugLog: String = "点击按钮开始测试连接..."

    /// 是否正在测试
    @State private var isTesting: Bool = false

    var body: some View {
        ZStack {
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                Text("Supabase 连接测试")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ApocalypseTheme.textPrimary)

                // 状态图标
                statusIcon
                    .padding(.vertical, 20)

                // 调试日志文本框
                ScrollView {
                    Text(debugLog)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(height: 200)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(12)

                // 测试按钮
                Button(action: testConnection) {
                    HStack {
                        if isTesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "network")
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTesting ? Color.gray : ApocalypseTheme.primary)
                    .cornerRadius(12)
                }
                .disabled(isTesting)

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Supabase 测试")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 状态图标
    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusBackgroundColor.opacity(0.2))
                .frame(width: 100, height: 100)

            Image(systemName: statusIconName)
                .font(.system(size: 50))
                .foregroundColor(statusIconColor)
        }
    }

    private var statusIconName: String {
        switch connectionStatus {
        case .none:
            return "questionmark.circle"
        case .some(true):
            return "checkmark.circle.fill"
        case .some(false):
            return "exclamationmark.circle.fill"
        }
    }

    private var statusIconColor: Color {
        switch connectionStatus {
        case .none:
            return ApocalypseTheme.textMuted
        case .some(true):
            return ApocalypseTheme.success
        case .some(false):
            return ApocalypseTheme.danger
        }
    }

    private var statusBackgroundColor: Color {
        switch connectionStatus {
        case .none:
            return ApocalypseTheme.textMuted
        case .some(true):
            return ApocalypseTheme.success
        case .some(false):
            return ApocalypseTheme.danger
        }
    }

    // MARK: - 测试连接
    private func testConnection() {
        isTesting = true
        connectionStatus = nil
        debugLog = "[\(timestamp)] 开始测试连接...\n"
        debugLog += "[\(timestamp)] URL: https://bgjosiapfuiuyuczxhgp.supabase.co\n"
        debugLog += "[\(timestamp)] 正在查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（不太可能），也算成功
                await MainActor.run {
                    connectionStatus = true
                    debugLog += "[\(timestamp)] ✅ 连接成功（查询完成）\n"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                    isTesting = false
                }
            }
        }
    }

    // MARK: - 错误处理
    private func handleError(_ error: Error) {
        let errorString = error.localizedDescription
        let errorDebug = String(describing: error)

        debugLog += "[\(timestamp)] 收到响应，分析中...\n"
        debugLog += "[\(timestamp)] 错误信息: \(errorString)\n"

        // 判断错误类型
        if errorDebug.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("relation") && errorString.contains("does not exist") ||
           errorDebug.contains("42P01") {
            // PostgreSQL 错误码或 PostgREST 错误，说明已连接到服务器
            connectionStatus = true
            debugLog += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(timestamp)] 说明：服务器返回了表不存在的错误，这表明连接正常\n"
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") ||
                  errorString.contains("network") ||
                  errorString.contains("Internet") {
            // 网络或 URL 错误
            connectionStatus = false
            debugLog += "[\(timestamp)] ❌ 连接失败：URL 错误或无网络\n"
            debugLog += "[\(timestamp)] 请检查网络连接和 Supabase URL\n"
        } else {
            // 其他错误
            connectionStatus = false
            debugLog += "[\(timestamp)] ❌ 连接失败\n"
            debugLog += "[\(timestamp)] 详细错误: \(errorDebug)\n"
        }
    }

    // MARK: - 时间戳
    private var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - 空响应模型
private struct EmptyResponse: Decodable {}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
