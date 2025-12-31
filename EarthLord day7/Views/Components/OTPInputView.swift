//
//  OTPInputView.swift
//  EarthLord day7
//
//  Created by 996 on 2025/12/30.
//

import SwiftUI

/// OTP验证码输入视图（6位独立方框）
struct OTPInputView: View {
    @Binding var otpCode: String
    @FocusState private var focusedField: Int?

    /// 验证码长度
    private let codeLength = 6

    /// 单个字符数组
    private var digits: [String] {
        var result: [String] = []
        for index in 0..<codeLength {
            if index < otpCode.count {
                let char = otpCode[otpCode.index(otpCode.startIndex, offsetBy: index)]
                result.append(String(char))
            } else {
                result.append("")
            }
        }
        return result
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<codeLength, id: \.self) { index in
                OTPDigitBox(
                    digit: digits[index],
                    isFocused: focusedField == index
                )
                .onTapGesture {
                    focusedField = index
                }
            }
        }
        .background(
            // 隐藏的TextField用于键盘输入
            TextField("", text: $otpCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: 0)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: otpCode) { oldValue, newValue in
                    // 限制只能输入6位数字
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count <= codeLength {
                        otpCode = filtered
                    } else {
                        otpCode = String(filtered.prefix(codeLength))
                    }
                }
        )
        .onAppear {
            // 自动聚焦到第一个输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = 0
            }
        }
    }
}

/// OTP单个数字框
struct OTPDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(ApocalypseTheme.cardBackground)

            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isFocused ? ApocalypseTheme.primary : ApocalypseTheme.textMuted.opacity(0.3),
                    lineWidth: isFocused ? 2 : 1
                )

            Text(digit)
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(ApocalypseTheme.textPrimary)
        }
        .frame(width: 48, height: 56)
    }
}

#Preview {
    VStack {
        OTPInputView(otpCode: .constant("123"))
            .padding()

        OTPInputView(otpCode: .constant("123456"))
            .padding()
    }
    .background(ApocalypseTheme.background)
}
