//
//  AuthManager.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/30.
//

import SwiftUI
import Combine
import Supabase
import GoogleSignIn
import AuthenticationServices
import CryptoKit

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

    // MARK: - 第三方登录

    /// Apple 登录
    /// 使用 AuthenticationServices 获取 identityToken，然后通过 Supabase 验证
    func signInWithApple() async {
        print("🍎 [Apple登录] 开始 Apple 登录流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 生成随机 nonce 用于安全验证
            let nonce = randomNonceString()
            let hashedNonce = sha256(nonce)

            // 创建 Apple ID 请求
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            print("🍎 [Apple登录] 正在请求 Apple 授权...")

            // 执行授权请求
            let result = try await performAppleSignIn(request: request)

            guard let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential else {
                print("❌ [Apple登录] 无法获取 Apple ID 凭证")
                errorMessage = "Apple 登录失败: 无法获取凭证"
                isLoading = false
                return
            }

            print("✅ [Apple登录] Apple 授权成功")
            print("🍎 [Apple登录] 用户ID: \(appleIDCredential.user)")

            // 获取 identityToken
            guard let identityTokenData = appleIDCredential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                print("❌ [Apple登录] 无法获取 identityToken")
                errorMessage = "Apple 登录失败: 无法获取令牌"
                isLoading = false
                return
            }

            print("🍎 [Apple登录] 成功获取 identityToken，正在向 Supabase 验证...")

            // 使用 identityToken 向 Supabase 进行身份验证
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: identityToken,
                    nonce: nonce
                )
            )

            currentUser = session.user
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ [Apple登录] Supabase 验证成功!")
            print("✅ [Apple登录] 用户ID: \(session.user.id)")
            print("✅ [Apple登录] 用户邮箱: \(session.user.email ?? "未知")")

        } catch let error as ASAuthorizationError where error.code == .canceled {
            // 用户取消登录，不显示错误
            print("ℹ️ [Apple登录] 用户取消了登录")
        } catch let error as ASAuthorizationError {
            // 其他 Apple Sign-In 错误
            print("❌ [Apple登录] 授权失败: \(error.localizedDescription)")
            errorMessage = "Apple 登录失败"
        } catch {
            print("❌ [Apple登录] 登录失败: \(error)")
            print("❌ [Apple登录] 错误详情: \(String(describing: error))")
            errorMessage = "Apple 登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 执行 Apple Sign In 请求
    /// 使用 async/await 包装 ASAuthorizationController
    private func performAppleSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)

            // 保持 delegate 引用
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    /// 生成随机 nonce 字符串
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    /// SHA256 哈希
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    /// Google 登录
    /// 使用 GoogleSignIn SDK 获取 ID Token，然后通过 Supabase 验证
    func signInWithGoogle() async {
        print("🔵 [Google登录] 开始 Google 登录流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 获取当前 window scene 用于展示 Google 登录界面
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ [Google登录] 无法获取根视图控制器")
                errorMessage = "无法启动 Google 登录"
                isLoading = false
                return
            }

            print("🔵 [Google登录] 正在调用 GoogleSignIn SDK...")

            // 调用 Google Sign-In（这是一个同步方法，但会显示登录界面）
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            print("✅ [Google登录] Google SDK 登录成功")
            print("🔵 [Google登录] 用户邮箱: \(result.user.profile?.email ?? "未知")")

            // 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ [Google登录] 无法获取 ID Token")
                errorMessage = "Google 登录失败: 无法获取令牌"
                isLoading = false
                return
            }

            print("🔵 [Google登录] 成功获取 ID Token，正在向 Supabase 验证...")

            // 使用 ID Token 向 Supabase 进行身份验证
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            currentUser = session.user
            isAuthenticated = true
            needsPasswordSetup = false

            print("✅ [Google登录] Supabase 验证成功!")
            print("✅ [Google登录] 用户ID: \(session.user.id)")
            print("✅ [Google登录] 用户邮箱: \(session.user.email ?? "未知")")

        } catch let error as GIDSignInError {
            // 处理 Google Sign-In 特定错误
            switch error.code {
            case .canceled:
                print("ℹ️ [Google登录] 用户取消了登录")
                // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                print("❌ [Google登录] 钥匙串中没有认证信息")
                errorMessage = "请重新登录 Google 账户"
            default:
                print("❌ [Google登录] Google SDK 错误: \(error.localizedDescription)")
                errorMessage = "Google 登录失败: \(error.localizedDescription)"
            }
        } catch {
            print("❌ [Google登录] 登录失败: \(error)")
            print("❌ [Google登录] 错误详情: \(String(describing: error))")
            errorMessage = "Google 登录失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - 删除账户

    /// 删除账户
    /// 调用边缘函数 delete-account 删除当前用户
    func deleteAccount() async -> Bool {
        print("🔵 [删除账户] 开始删除账户流程...")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前会话的 access token
            let session = try await supabase.auth.session
            let accessToken = session.accessToken
            print("🔵 [删除账户] 已获取用户令牌")

            // 2. 构建请求 URL
            guard let url = URL(string: "https://bgjosiapfuiuyuczxhgp.supabase.co/functions/v1/delete-account") else {
                print("❌ [删除账户] 无效的 URL")
                errorMessage = "删除账户失败：无效的请求地址"
                isLoading = false
                return false
            }

            // 3. 创建请求
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            print("🔵 [删除账户] 正在调用边缘函数...")

            // 4. 发送请求
            let (data, response) = try await URLSession.shared.data(for: request)

            // 5. 检查响应状态码
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [删除账户] 无效的响应")
                errorMessage = "删除账户失败：服务器响应无效"
                isLoading = false
                return false
            }

            print("🔵 [删除账户] 响应状态码: \(httpResponse.statusCode)")

            // 6. 解析响应
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔵 [删除账户] 响应内容: \(responseString)")
            }

            if httpResponse.statusCode == 200 {
                print("✅ [删除账户] 账户删除成功")

                // 7. 清空本地状态
                currentUser = nil
                isAuthenticated = false
                needsPasswordSetup = false
                otpSent = false
                otpVerified = false
                isInPasswordSetupFlow = false

                isLoading = false
                return true
            } else {
                // 解析错误信息
                if let json = try? JSONDecoder().decode([String: String].self, from: data),
                   let error = json["error"] {
                    errorMessage = error
                    print("❌ [删除账户] 服务器错误: \(error)")
                } else {
                    errorMessage = "删除账户失败：服务器错误 (\(httpResponse.statusCode))"
                    print("❌ [删除账户] HTTP 错误: \(httpResponse.statusCode)")
                }
                isLoading = false
                return false
            }

        } catch {
            print("❌ [删除账户] 请求失败: \(error)")
            print("❌ [删除账户] 错误详情: \(String(describing: error))")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - 其他方法

    /// 登出
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()
            print("✅ 登出成功")
        } catch {
            // sessionMissing 错误表示 session 已经不存在，视为登出成功
            let errorDesc = error.localizedDescription.lowercased()
            if errorDesc.contains("session") && errorDesc.contains("missing") {
                print("⚠️ Session 已不存在，视为登出成功")
            } else {
                errorMessage = "登出失败: \(error.localizedDescription)"
                print("❌ 登出失败: \(error)")
                isLoading = false
                return
            }
        }

        // 清空状态（无论 signOut 是否抛出 sessionMissing 错误）
        currentUser = nil
        isAuthenticated = false
        needsPasswordSetup = false
        otpSent = false
        otpVerified = false
        isInPasswordSetupFlow = false

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

// MARK: - Apple Sign In Delegate

/// Apple Sign In 代理类
/// 用于桥接 ASAuthorizationController 的 delegate 模式到 async/await
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    private let continuation: CheckedContinuation<ASAuthorization, Error>

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }

    // MARK: - ASAuthorizationControllerPresentationContextProviding

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}
