//
//  TerritoryTestView.swift
//  EarthLord day7
//
//  圈地功能测试界面
//  显示实时日志、状态信息，支持清空和导出日志
//
//  ⚠️ 注意：此视图不套 NavigationStack，因为它已经在父级导航栈内
//

import SwiftUI

/// 圈地功能测试界面
struct TerritoryTestView: View {

    // MARK: - 环境对象
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var locationManager: LocationManager

    // MARK: - 状态
    @ObservedObject private var logger = TerritoryLogger.shared

    /// 是否显示分享面板
    @State private var showShareSheet = false

    /// 导出的日志文本
    @State private var exportedLog = ""

    var body: some View {
        ZStack {
            // 背景
            ApocalypseTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 状态指示区
                statusSection

                // 日志区域
                logSection

                // 底部按钮
                buttonSection
            }
        }
        .navigationTitle(languageManager.localizedString("圈地功能测试"))
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: exportedLog)
        }
        .onAppear {
            // 进入页面时记录一条日志
            TerritoryLogger.shared.log(languageManager.localizedString("进入圈地测试界面"), type: .info)
        }
    }

    // MARK: - 状态指示区

    private var statusSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                // 定位状态
                statusItem(
                    icon: locationManager.userLocation != nil ? "location.fill" : "location.slash",
                    color: locationManager.userLocation != nil ? .green : .red,
                    title: languageManager.localizedString("定位"),
                    value: locationManager.userLocation != nil ?
                        languageManager.localizedString("已定位") :
                        languageManager.localizedString("未定位")
                )

                // 追踪状态
                statusItem(
                    icon: locationManager.isTracking ? "figure.walk" : "figure.stand",
                    color: locationManager.isTracking ? ApocalypseTheme.primary : .gray,
                    title: languageManager.localizedString("追踪"),
                    value: locationManager.isTracking ?
                        languageManager.localizedString("进行中") :
                        languageManager.localizedString("未开始")
                )

                // 路径点数
                statusItem(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    color: .cyan,
                    title: languageManager.localizedString("路径点"),
                    value: "\(locationManager.pathCoordinates.count)"
                )

                // 闭合状态
                statusItem(
                    icon: locationManager.isPathClosed ? "checkmark.seal.fill" : "seal",
                    color: locationManager.isPathClosed ? .green : .gray,
                    title: languageManager.localizedString("闭合"),
                    value: locationManager.isPathClosed ?
                        languageManager.localizedString("已闭合") :
                        languageManager.localizedString("未闭合")
                )
            }

            // 速度警告
            if locationManager.isOverSpeed {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(languageManager.localizedString("速度超限"))
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.2))
                .cornerRadius(8)
            } else if locationManager.speedWarning != nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(languageManager.localizedString("速度警告"))
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }

    private func statusItem(icon: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(ApocalypseTheme.textSecondary)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 日志区域

    private var logSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logger.logs) { entry in
                        logEntryView(entry)
                            .id(entry.id)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.3))
            .onChange(of: logger.logs.count) { _, _ in
                // 自动滚动到底部
                if let lastLog = logger.logs.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logEntryView(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 时间戳
            Text(formatTime(entry.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textMuted)

            // 类型标签
            Text("[\(entry.type.rawValue)]")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(colorForLogType(entry.type))

            // 消息
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func colorForLogType(_ type: LogType) -> Color {
        switch type {
        case .info:
            return .cyan
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    // MARK: - 底部按钮

    private var buttonSection: some View {
        HStack(spacing: 16) {
            // 清空按钮
            Button {
                logger.clear()
                TerritoryLogger.shared.log(languageManager.localizedString("日志已清空"), type: .info)
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(languageManager.localizedString("清空日志"))
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.cardBackground)
                .cornerRadius(10)
            }

            // 导出按钮
            Button {
                exportedLog = logger.export()
                showShareSheet = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(languageManager.localizedString("导出日志"))
                }
                .font(.subheadline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(ApocalypseTheme.primary)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
    }
}

// MARK: - 分享面板

struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        TerritoryTestView()
            .environmentObject(LanguageManager.shared)
            .environmentObject(LocationManager.shared)
    }
}
