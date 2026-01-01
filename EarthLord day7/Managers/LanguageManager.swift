//
//  LanguageManager.swift
//  EarthLord day7
//
//  Created by Claude on 2025/01/01.
//

import SwiftUI
import Combine

/// 支持的语言选项
enum AppLanguage: String, CaseIterable {
    case system = "system"      // 跟随系统
    case zhHans = "zh-Hans"     // 简体中文
    case en = "en"              // English

    /// 显示名称
    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }

    /// 本地化的显示名称（用于当前语言环境）
    func localizedDisplayName(for currentLanguage: String) -> String {
        switch self {
        case .system:
            return currentLanguage == "en" ? "Follow System" : "跟随系统"
        case .zhHans:
            return "简体中文"
        case .en:
            return "English"
        }
    }
}

/// 语言管理器
/// 负责 App 内语言切换、持久化存储、实时更新
class LanguageManager: ObservableObject {

    // MARK: - Singleton

    static let shared = LanguageManager()

    // MARK: - Published Properties

    /// 当前选择的语言选项
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: languageKey)
            updateCurrentLocale()
            print("✅ [语言] 切换到: \(selectedLanguage.displayName)")
        }
    }

    /// 当前实际使用的语言代码（用于加载本地化资源）
    @Published private(set) var currentLanguageCode: String = "zh-Hans"

    // MARK: - Private Properties

    private let languageKey = "app_language_preference"

    /// 本地化 Bundle 缓存
    private var localizedBundle: Bundle?

    // MARK: - Initialization

    init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }

        updateCurrentLocale()
        print("🔵 [语言] 初始化完成，当前语言: \(currentLanguageCode)")
    }

    // MARK: - Public Methods

    /// 获取本地化字符串
    /// - Parameter key: 本地化 key
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String) -> String {
        guard let bundle = getLocalizedBundle() else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }

    /// 获取带参数的本地化字符串
    /// - Parameters:
    ///   - key: 本地化 key
    ///   - arguments: 格式化参数
    /// - Returns: 本地化后的字符串
    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }

    // MARK: - Private Methods

    /// 更新当前语言代码
    private func updateCurrentLocale() {
        switch selectedLanguage {
        case .system:
            // 跟随系统语言
            let systemLanguage = Locale.preferredLanguages.first ?? "zh-Hans"
            if systemLanguage.hasPrefix("zh") {
                currentLanguageCode = "zh-Hans"
            } else {
                currentLanguageCode = "en"
            }
        case .zhHans:
            currentLanguageCode = "zh-Hans"
        case .en:
            currentLanguageCode = "en"
        }

        // 清除缓存的 bundle，下次获取时重新加载
        localizedBundle = nil
    }

    /// 获取对应语言的 Bundle
    private func getLocalizedBundle() -> Bundle? {
        if let cached = localizedBundle {
            return cached
        }

        // 尝试加载对应语言的 lproj
        if let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localizedBundle = bundle
            return bundle
        }

        // 如果是 zh-Hans，也尝试 zh
        if currentLanguageCode == "zh-Hans" {
            if let path = Bundle.main.path(forResource: "zh", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                localizedBundle = bundle
                return bundle
            }
        }

        // 回退到主 bundle
        return Bundle.main
    }
}

// MARK: - LocalizedText View

/// 自动响应语言切换的本地化文本视图
struct LocalizedText: View {
    @EnvironmentObject var languageManager: LanguageManager

    let key: String
    let arguments: [CVarArg]

    init(_ key: String) {
        self.key = key
        self.arguments = []
    }

    init(_ key: String, _ arguments: CVarArg...) {
        self.key = key
        self.arguments = arguments
    }

    var body: some View {
        if arguments.isEmpty {
            Text(languageManager.localizedString(key))
        } else {
            Text(String(format: languageManager.localizedString(key), arguments: arguments))
        }
    }
}

// MARK: - String Extension

extension String {
    /// 获取本地化字符串（需要在有 LanguageManager 环境的视图中使用）
    func localized(with manager: LanguageManager) -> String {
        return manager.localizedString(self)
    }
}
