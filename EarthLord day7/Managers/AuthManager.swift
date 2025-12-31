//
//  AuthManager.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/30.
//

import SwiftUI
import Combine
import Supabase

/// 认证管理器
/// 负责用户注册、登录、找回密码、第三方登录等认证相关功能
@MainActor
class AuthManager: ObservableObject {

    // MARK: - Published Properties

    /// 用户是否已完成认证（登录且完成所有必要流程）
    @Published var isAuthenticated: Bool = false

    /// 是否需要设置密码（OTP验证后必须设置密码才能进入主页）
    @Published var needsPasswordSetup: Bool = false

    /// 当前登录用户
    @Published var currentUser: User? = nil

    /// 是否正在加载
    @Published var isLoading: Bool = false

    /// 错误信息
    @Published var errorMessage: String? = nil

    /// OTP验证码是否已发送
    @Published var otpSent: Bool = false

    /// OTP验证码是否已验证（等待设置密码）
    @Published var otpVerified: Bool = false

    // MARK: - Private Properties

    /// 认证状态监听取消令牌
    private var authStateTask: Task<Void, Never>?

    /// 是否正在注册/重置密码流程中
    private var isInPasswordSetupFlow: Bool = false

    // MARK: - Initialization

    init() {
        // 初始化时检查会话
        Task {
            await checkSession()
            await setupAuthListener()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - 认证状态监听

    /// 设置认证状态变化监听
    private func setupAuthListener() async {
        authStateTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await handleAuthStateChange(event: event, session: session)
            }
        }
    }

    /// 处理认证状态变化
    /// - Parameters:
    ///   - event: 认证事件
    ///   - session: 会话信息
    private func handleAuthStateChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn:
            // 用户登录
            if let session = session {
                currentUser = session.user

                // 如果正在注册/重置密码流程中，不直接设置为已认证
                if isInPasswordSetupFlow {
                    needsPasswordSetup = true
                    isAuthenticated = false
                    print("✅ 认证状态变化: OTP验证成功，等待设置密码 - \(session.user.email ?? "unknown")")
                } else {
                    isAuthenticated = true
                    needsPasswordSetup = false
                    print("✅ 认证状态变化: 已登录 - \(session.user.email ?? "unknown")")
                }
            }

        case .signedOut:
            // 用户登出
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            print("ℹ️ 认证状态变化: 已登出")

        case .tokenRefreshed:
            // Token 刷新
            if let session = session {
                currentUser = session.user
                print("ℹ️ 认证状态变化: Token 已刷新")
            }

        case .userUpdated:
            // 用户信息更新
            if let session = session {
                currentUser = session.user
                print("ℹ️ 认证状态变化: 用户信息已更新")
            }

        case .userDeleted:
            // 用户删除
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            print("ℹ️ 认证状态变化: 用户已删除")

        case .mfaChallengeVerified:
            // MFA 验证完成
            print("ℹ️ 认证状态变化: MFA 验证完成")

        case .passwordRecovery:
            // 密码恢复
            print("ℹ️ 认证状态变化: 密码恢复流程")
        }
    }

    // MARK: - 注册流程

    /// 检查邮箱是否已注册
    /// - Parameter email: 用户邮箱
    /// - Returns: true表示邮箱已存在，false表示可以注册
    private func checkEmailExists(email: String) async -> Bool {
        do {
            // 调用 Supabase RPC 函数检查邮箱是否存在
            let response = try await supabase.rpc("check_email_exists", params: ["check_email": email]).execute()

            // 解析布尔值返回结果
            let decoder = JSONDecoder()
            let exists = try decoder.decode(Bool.self, from: response.data)

            print("✅ 邮箱检查结果 [\(email)]: \(exists ? "已存在" : "可注册")")
            return exists

        } catch {
            // 如果 RPC 函数不存在或调用失败
            print("❌ 检查邮箱失败: \(error.localizedDescription)")
            print("💡 提示：请在 Supabase 后台执行 SQL 创建 check_email_exists 函数")
            print("💡 如果函数已创建，请检查函数名称和参数是否正确")

            // 检查失败时，为了安全起见，返回 false（允许继续）
            // 如果你希望检查失败时阻止注册，可以改为 return true
            return false
        }
    }

    /// 步骤1：发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        // 第一步：检查邮箱是否已注册（不使用 try，因为该方法不会抛出错误）
        let emailExists = await checkEmailExists(email: email)

        if emailExists {
            // 邮箱已存在，显示错误并返回（不发送邮件）
            errorMessage = "该邮箱已注册，请直接登录"
            isLoading = false
            print("⚠️ 注册被阻止：邮箱已存在 - \(email)")
            return
        }

        // 第二步：邮箱未注册，发送 OTP
        do {
            print("📧 开始发送注册验证码到: \(email)")

            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("✅ 注册验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送验证码失败: \(error.localizedDescription)"
            print("❌ 发送注册OTP失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤2：验证注册验证码
    /// ⚠️ 验证成功后用户已登录，但需要强制设置密码才能进入主页
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 标记进入密码设置流程
            isInPasswordSetupFlow = true

            // 验证 OTP（用户此时已登录）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，强制用户设置密码

            print("✅ 验证码验证成功，用户已登录，等待设置密码")

        } catch {
            isInPasswordSetupFlow = false
            errorMessage = "验证码错误: \(error.localizedDescription)"
            print("❌ 验证注册OTP失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤3：完成注册（设置密码）
    /// 必须在 verifyRegisterOTP 成功后调用
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        guard otpVerified else {
            errorMessage = "请先验证邮箱"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true

            // 重置注册流程标记
            otpSent = false
            otpVerified = false
            isInPasswordSetupFlow = false

            print("✅ 注册完成，密码已设置")

        } catch {
            errorMessage = "设置密码失败: \(error.localizedDescription)"
            print("❌ 完成注册失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 邮箱密码登录
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = session.user
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = "登录失败: \(error.localizedDescription)"
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 步骤1：发送重置密码验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        isLoading = true
        errorMessage = nil
        otpSent = false

        do {
            // 发送密码重置邮件（触发 Reset Password 邮件模板）
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("✅ 密码重置验证码已发送到: \(email)")

        } catch {
            errorMessage = "发送重置邮件失败: \(error.localizedDescription)"
            print("❌ 发送重置OTP失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤2：验证重置密码验证码
    /// ⚠️ 注意：type 必须是 .recovery 而不是 .email
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        isLoading = true
        errorMessage = nil

        do {
            // 标记进入密码设置流程
            isInPasswordSetupFlow = true

            // 验证恢复码（type 是 .recovery）
            let session = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            currentUser = session.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置验证码验证成功，等待设置新密码")

        } catch {
            isInPasswordSetupFlow = false
            errorMessage = "验证码错误: \(error.localizedDescription)"
            print("❌ 验证重置OTP失败: \(error)")
        }

        isLoading = false
    }

    /// 步骤3：重置密码
    /// 必须在 verifyResetOTP 成功后调用
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        guard otpVerified else {
            errorMessage = "请先验证邮箱"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true

            // 重置流程标记
            otpSent = false
            otpVerified = false
            isInPasswordSetupFlow = false

            print("✅ 密码重置成功")

        } catch {
            errorMessage = "重置密码失败: \(error.localizedDescription)"
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Apple Sign In
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        errorMessage = "Apple 登录功能即将推出"
        print("⚠️ Apple 登录尚未实现")
    }

    /// Google 登录
    /// TODO: 实现 Google Sign In
    func signInWithGoogle() async {
        // TODO: 实现 Google 登录
        errorMessage = "Google 登录功能即将推出"
        print("⚠️ Google 登录尚未实现")
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 清空状态
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false
            otpSent = false
            otpVerified = false
            isInPasswordSetupFlow = false

            print("✅ 登出成功")

        } catch {
            errorMessage = "登出失败: \(error.localizedDescription)"
            print("❌ 登出失败: \(error)")
        }

        isLoading = false
    }

    /// 检查会话状态
    /// 启动时调用，恢复登录状态
    func checkSession() async {
        do {
            // 获取当前会话
            let session = try await supabase.auth.session

            currentUser = session.user

            // 检查用户是否设置了密码
            // 如果用户通过 OTP 登录但未设置密码，需要强制设置
            // 这里简单判断：如果有 session 就认为已完成所有流程
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ 会话恢复成功: \(session.user.email ?? "unknown")")

        } catch {
            // 没有有效会话
            currentUser = nil
            isAuthenticated = false
            needsPasswordSetup = false

            print("ℹ️ 没有有效会话")
        }
    }
}
