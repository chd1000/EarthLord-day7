//
//  CreateChannelSheet.swift
//  EarthLord day7
//
//  创建频道页面
//

import SwiftUI
import Supabase

struct CreateChannelSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var communicationManager = CommunicationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ChannelType = .publicChannel
    @State private var channelName = ""
    @State private var channelDescription = ""
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 频道类型选择
                    channelTypeSection

                    // 频道名称
                    channelNameSection

                    // 频道描述
                    channelDescriptionSection

                    // 创建按钮
                    createButton

                    // 错误信息
                    if let error = communicationManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.error)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ApocalypseTheme.background)
            .onTapGesture {
                // 点击空白区域收起键盘
                UIApplication.shared.dismissKeyboard()
            }
            .navigationTitle("创建频道")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - 频道类型选择

    private var channelTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("频道类型")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ChannelType.creatableTypes, id: \.self) { type in
                    ChannelTypeCard(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedType = type
                        }
                    }
                }
            }
        }
    }

    // MARK: - 频道名称

    private var channelNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("频道名称")
                    .font(.headline)
                    .foregroundColor(ApocalypseTheme.textPrimary)
                Text("*")
                    .foregroundColor(ApocalypseTheme.error)
            }

            TextField("输入频道名称", text: $channelName)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .background(ApocalypseTheme.surface)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)

            HStack {
                Text("\(channelName.count)/50")
                    .font(.caption)
                    .foregroundColor(isNameValid ? ApocalypseTheme.textSecondary : ApocalypseTheme.error)
                Spacer()
                if !isNameValid && !channelName.isEmpty {
                    Text("名称需要2-50个字符")
                        .font(.caption)
                        .foregroundColor(ApocalypseTheme.error)
                }
            }
        }
    }

    // MARK: - 频道描述

    private var channelDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("频道描述（可选）")
                .font(.headline)
                .foregroundColor(ApocalypseTheme.textPrimary)

            TextEditor(text: $channelDescription)
                .frame(minHeight: 100)
                .padding(8)
                .background(ApocalypseTheme.surface)
                .cornerRadius(10)
                .foregroundColor(ApocalypseTheme.textPrimary)
                .scrollContentBackground(.hidden)

            Text("\(channelDescription.count)/200")
                .font(.caption)
                .foregroundColor(channelDescription.count <= 200 ? ApocalypseTheme.textSecondary : ApocalypseTheme.error)
        }
    }

    // MARK: - 创建按钮

    private var createButton: some View {
        Button {
            Task {
                await createChannel()
            }
        } label: {
            HStack {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(isCreating ? "创建中..." : "创建频道")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCreate ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCreate || isCreating)
    }

    // MARK: - 计算属性

    private var isNameValid: Bool {
        channelName.count >= 2 && channelName.count <= 50
    }

    private var canCreate: Bool {
        isNameValid && channelDescription.count <= 200
    }

    // MARK: - 方法

    private func createChannel() async {
        guard let userId = authManager.currentUser?.id else { return }

        isCreating = true

        await communicationManager.createChannel(
            userId: userId,
            type: selectedType,
            name: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: channelDescription.isEmpty ? nil : channelDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        isCreating = false

        if communicationManager.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - 频道类型卡片

struct ChannelTypeCard: View {
    let type: ChannelType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: type.iconName)
                        .font(.title2)
                        .foregroundColor(typeColor)
                }

                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? ApocalypseTheme.textPrimary : ApocalypseTheme.textSecondary)

                Text(type.description)
                    .font(.caption2)
                    .foregroundColor(ApocalypseTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ApocalypseTheme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? typeColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeColor: Color {
        switch type {
        case .official: return ApocalypseTheme.warning
        case .publicChannel: return ApocalypseTheme.primary
        case .walkie: return ApocalypseTheme.success
        case .camp: return ApocalypseTheme.secondary
        case .satellite: return ApocalypseTheme.info
        }
    }
}

#Preview {
    CreateChannelSheet()
        .environmentObject(AuthManager())
}
