//
//  CallsignSettingsSheet.swift
//  EarthLord day7
//
//  呼号设置弹窗
//

import SwiftUI

struct CallsignSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communicationManager = CommunicationManager.shared

    @State private var callsign: String = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 图标和说明
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(ApocalypseTheme.primary.opacity(0.2))
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 36))
                            .foregroundColor(ApocalypseTheme.primary)
                    }

                    Text("设置你的呼号")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ApocalypseTheme.textPrimary)

                    Text("呼号将在频道消息中显示，方便其他幸存者识别你")
                        .font(.subheadline)
                        .foregroundColor(ApocalypseTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)

                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("呼号")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ApocalypseTheme.textSecondary)

                    TextField("例如：夜行者、幸存者007", text: $callsign)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                        .foregroundColor(ApocalypseTheme.textPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ApocalypseTheme.primary.opacity(0.3), lineWidth: 1)
                        )

                    HStack {
                        Text("最多20个字符")
                            .font(.caption)
                            .foregroundColor(ApocalypseTheme.textSecondary)
                        Spacer()
                        Text("\(callsign.count)/20")
                            .font(.caption)
                            .foregroundColor(callsign.count > 20 ? ApocalypseTheme.danger : ApocalypseTheme.textSecondary)
                    }
                }
                .padding(.horizontal)

                // 预览
                if !callsign.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览效果")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ApocalypseTheme.textSecondary)

                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(ApocalypseTheme.primary.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                Text(String(callsign.prefix(1)))
                                    .font(.headline)
                                    .foregroundColor(ApocalypseTheme.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(callsign)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(ApocalypseTheme.primary)
                                Text("这是一条示例消息...")
                                    .font(.body)
                                    .foregroundColor(ApocalypseTheme.textPrimary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(ApocalypseTheme.cardBackground)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // 保存按钮
                Button {
                    Task {
                        await saveCallsign()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("保存呼号")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? ApocalypseTheme.primary : ApocalypseTheme.textSecondary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canSave || isSaving)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(ApocalypseTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(ApocalypseTheme.textSecondary)
                }
            }
            .task {
                await loadCurrentCallsign()
            }
            .alert("保存成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("你的呼号已更新为「\(callsign)」")
            }
        }
    }

    private var canSave: Bool {
        !callsign.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && callsign.count <= 20
    }

    private func loadCurrentCallsign() async {
        isLoading = true
        if let profile = await communicationManager.getOrCreateUserProfile() {
            callsign = profile.callsign ?? ""
        }
        isLoading = false
    }

    private func saveCallsign() async {
        let trimmedCallsign = callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCallsign.isEmpty else { return }

        isSaving = true
        let success = await communicationManager.updateUserCallsign(trimmedCallsign)
        isSaving = false

        if success {
            showSuccessAlert = true
        }
    }
}

#Preview {
    CallsignSettingsSheet()
}
