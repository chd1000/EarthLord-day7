//
//  AuthView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/30.
//

import SwiftUI

/// 认证页面（登录/注册）
struct AuthView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var languageManager: LanguageManager

    /// 当前选中的Tab（0=登录, 1=注册）
    @State private var selectedTab: Int = 0

    /// 是否显示忘记密码弹窗
    @State private var showResetPassword: Bool = false

    /// 登录表单
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    /// 注册表单
    @State private var registerEmail: String = ""
    @State private var registerCode: String = ""
    @State private var registerPassword: String = ""
    @State private var registerConfirmPassword: String = ""

    /// 找回密码表单
    @State private var resetEmail: String = ""
    @State private var resetCode: String = ""
    @State private var resetNewPassword: String = ""
    @State private var resetConfirmPassword: String = ""

    /// 重发验证码倒计时
    @State private var resendCountdown: Int = 0
    @State private var resendTimer: Timer? = nil

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.10, blue: 0.18),
                    Color(red: 0.09, green: 0.13, blue: 0.24),
                    Color(red: 0.06, green: 0.06, blue: 0.10)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // 顶部 Logo 和标题
                    headerView

                    // Tab 切换
                    tabSwitcher

                    // 内容区域
                    if selectedTab == 0 {
                        loginTabView
                    } else {
                        registerTabView
                    }

                    // 第三方登录
                    thirdPartyLoginView
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }

            // 加载指示器
            if authManager.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
        .sheet(isPresented: $showResetPassword) {
            resetPasswordSheet
        }
        .alert(languageManager.localizedString("错误"), isPresented: .constant(authManager.errorMessage != nil)) {
            Button(languageManager.localizedString("确定")) {
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
    }

    // MARK: - 头部视图

    private var headerView: some View {
        VStack(spacing: 16) {
            // Logo
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ApocalypseTheme.primary,
                            ApocalypseTheme.primary.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                )
                .shadow(color: ApocalypseTheme.primary.opacity(0.3), radius: 20)

            // 标题
            Text(languageManager.localizedString("地球新主"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ApocalypseTheme.textPrimary)

            Text("EARTH LORD")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ApocalypseTheme.textSecondary)
                .tracking(3)
        }
        .padding(.top, 20)
    }

    // MARK: - Tab 切换器

    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            // 登录 Tab
            Button {
                withAnimation {
                    selectedTab = 0
                }
            } label: {
                Text(languageManager.localizedString("登录"))
                    .font(.headline)
                    .foregroundColor(selectedTab == 0 ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }

            // 注册 Tab
            Button {
                withAnimation {
                    selectedTab = 1
                }
            } label: {
                Text(languageManager.localizedString("注册"))
                    .font(.headline)
                    .foregroundColor(selectedTab == 1 ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            GeometryReader { geometry in
                ApocalypseTheme.primary
                    .frame(width: geometry.size.width / 2, height: 2)
                    .offset(x: selectedTab == 0 ? 0 : geometry.size.width / 2)
                    .animation(.spring(), value: selectedTab)
            }
            .frame(height: 2),
            alignment: .bottom
        )
    }

    // MARK: - 登录 Tab

    private var loginTabView: some View {
        VStack(spacing: 16) {
            // 邮箱输入
            CustomTextField(
                icon: "envelope",
                placeholder: languageManager.localizedString("邮箱"),
                text: $loginEmail
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            // 密码输入
            CustomSecureField(
                icon: "lock",
                placeholder: languageManager.localizedString("密码"),
                text: $loginPassword
            )

            // 登录按钮
            Button {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            } label: {
                Text(languageManager.localizedString("登录"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(loginEmail.isEmpty || loginPassword.isEmpty)
            .opacity(loginEmail.isEmpty || loginPassword.isEmpty ? 0.5 : 1.0)

            // 忘记密码
            Button {
                showResetPassword = true
            } label: {
                Text(languageManager.localizedString("忘记密码？"))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.primary)
            }
        }
    }

    // MARK: - 注册 Tab（三步流程）

    private var registerTabView: some View {
        VStack(spacing: 16) {
            if !authManager.otpSent {
                // 第一步：输入邮箱，发送验证码
                registerStep1
            } else if !authManager.otpVerified {
                // 第二步：输入验证码，验证
                registerStep2
            } else {
                // 第三步：设置密码
                registerStep3
            }
        }
    }

    // 注册第一步：发送验证码
    private var registerStep1: some View {
        VStack(spacing: 16) {
            Text(languageManager.localizedString("输入邮箱获取验证码"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope",
                placeholder: languageManager.localizedString("邮箱"),
                text: $registerEmail
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            Button {
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                    if authManager.otpSent {
                        startResendCountdown()
                    }
                }
            } label: {
                Text(languageManager.localizedString("发送验证码"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerEmail.isEmpty)
            .opacity(registerEmail.isEmpty ? 0.5 : 1.0)
        }
    }

    // 注册第二步：验证码输入
    private var registerStep2: some View {
        VStack(spacing: 16) {
            Text(languageManager.localizedString("验证码已发送到 %@", registerEmail))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            OTPInputView(otpCode: $registerCode)

            Button {
                Task {
                    await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
                }
            } label: {
                Text(languageManager.localizedString("验证"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerCode.count != 6)
            .opacity(registerCode.count != 6 ? 0.5 : 1.0)

            // 重发倒计时
            if resendCountdown > 0 {
                Text(languageManager.localizedString("重新发送 (%llds)", resendCountdown))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button {
                    Task {
                        await authManager.sendRegisterOTP(email: registerEmail)
                        startResendCountdown()
                    }
                } label: {
                    Text(languageManager.localizedString("重新发送验证码"))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // 注册第三步：设置密码
    private var registerStep3: some View {
        VStack(spacing: 16) {
            Text(languageManager.localizedString("设置密码完成注册"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock",
                placeholder: languageManager.localizedString("密码（至少6位）"),
                text: $registerPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: languageManager.localizedString("确认密码"),
                text: $registerConfirmPassword
            )

            // 密码匹配提示
            if !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text(languageManager.localizedString("密码不一致"))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button {
                Task {
                    await authManager.completeRegistration(password: registerPassword)
                }
            } label: {
                Text(languageManager.localizedString("完成注册"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(registerPassword.count < 6 || registerPassword != registerConfirmPassword)
            .opacity(registerPassword.count < 6 || registerPassword != registerConfirmPassword ? 0.5 : 1.0)
        }
    }

    // MARK: - 忘记密码弹窗

    private var resetPasswordSheet: some View {
        NavigationStack {
            ZStack {
                ApocalypseTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        if !authManager.otpSent {
                            // 第一步：发送重置验证码
                            resetPasswordStep1
                        } else if !authManager.otpVerified {
                            // 第二步：验证码输入
                            resetPasswordStep2
                        } else {
                            // 第三步：设置新密码
                            resetPasswordStep3
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(languageManager.localizedString("找回密码"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageManager.localizedString("取消")) {
                        showResetPassword = false
                        resetResetPasswordForm()
                    }
                }
            }
        }
    }

    // 重置密码第一步
    private var resetPasswordStep1: some View {
        VStack(spacing: 16) {
            Text(languageManager.localizedString("输入邮箱获取验证码"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomTextField(
                icon: "envelope",
                placeholder: languageManager.localizedString("邮箱"),
                text: $resetEmail
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)

            Button {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                    if authManager.otpSent {
                        startResendCountdown()
                    }
                }
            } label: {
                Text(languageManager.localizedString("发送验证码"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(resetEmail.isEmpty)
            .opacity(resetEmail.isEmpty ? 0.5 : 1.0)
        }
    }

    // 重置密码第二步
    private var resetPasswordStep2: some View {
        VStack(spacing: 16) {
            Text(languageManager.localizedString("验证码已发送到 %@", resetEmail))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)

            OTPInputView(otpCode: $resetCode)

            Button {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetCode)
                }
            } label: {
                Text(languageManager.localizedString("验证"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(resetCode.count != 6)
            .opacity(resetCode.count != 6 ? 0.5 : 1.0)

            // 重发倒计时
            if resendCountdown > 0 {
                Text(languageManager.localizedString("重新发送 (%llds)", resendCountdown))
                    .font(.subheadline)
                    .foregroundColor(ApocalypseTheme.textMuted)
            } else {
                Button {
                    Task {
                        await authManager.sendResetOTP(email: resetEmail)
                        startResendCountdown()
                    }
                } label: {
                    Text(languageManager.localizedString("重新发送验证码"))
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.primary)
                }
            }
        }
    }

    // 重置密码第三步
    private var resetPasswordStep3: some View {
        VStack(spacing: 16) {
            Text(languageManager.localizedString("设置新密码"))
                .font(.subheadline)
                .foregroundColor(ApocalypseTheme.textSecondary)

            CustomSecureField(
                icon: "lock",
                placeholder: languageManager.localizedString("新密码（至少6位）"),
                text: $resetNewPassword
            )

            CustomSecureField(
                icon: "lock.fill",
                placeholder: languageManager.localizedString("确认新密码"),
                text: $resetConfirmPassword
            )

            // 密码匹配提示
            if !resetConfirmPassword.isEmpty && resetNewPassword != resetConfirmPassword {
                Text(languageManager.localizedString("密码不一致"))
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
            }

            Button {
                Task {
                    await authManager.resetPassword(newPassword: resetNewPassword)
                    if authManager.isAuthenticated {
                        showResetPassword = false
                        resetResetPasswordForm()
                    }
                }
            } label: {
                Text(languageManager.localizedString("重置密码"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .disabled(resetNewPassword.count < 6 || resetNewPassword != resetConfirmPassword)
            .opacity(resetNewPassword.count < 6 || resetNewPassword != resetConfirmPassword ? 0.5 : 1.0)
        }
    }

    // MARK: - 第三方登录

    private var thirdPartyLoginView: some View {
        VStack(spacing: 16) {
            // 分隔线
            HStack(spacing: 12) {
                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)

                Text(languageManager.localizedString("或者使用以下方式登录"))
                    .font(.system(size: 11))
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .lineLimit(1)
                    .fixedSize()

                Rectangle()
                    .fill(ApocalypseTheme.textMuted.opacity(0.3))
                    .frame(height: 1)
            }

            // Apple 登录按钮
            Button {
                Task {
                    await authManager.signInWithApple()
                }
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                    Text(languageManager.localizedString("使用 Apple 登录"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(12)
            }

            // Google 登录按钮
            Button {
                Task {
                    await authManager.signInWithGoogle()
                }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text(languageManager.localizedString("使用 Google 登录"))
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - 辅助方法

    /// 启动重发倒计时
    private func startResendCountdown() {
        resendCountdown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if resendCountdown > 0 {
                resendCountdown -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }

    /// 重置找回密码表单
    private func resetResetPasswordForm() {
        resetEmail = ""
        resetCode = ""
        resetNewPassword = ""
        resetConfirmPassword = ""
        authManager.otpSent = false
        authManager.otpVerified = false
        resendTimer?.invalidate()
        resendCountdown = 0
    }
}

// MARK: - 自定义输入框组件

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ApocalypseTheme.textMuted)
                .frame(width: 20)

            SecureField(placeholder, text: $text)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .padding()
        .background(ApocalypseTheme.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
        .environmentObject(LanguageManager.shared)
}
