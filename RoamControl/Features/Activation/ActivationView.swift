import SwiftUI

struct ActivationSummaryView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(appModel.activation.phase.title, systemImage: appModel.activation.isAuthorized ? "checkmark.shield.fill" : "key.fill")
                .font(.headline)
                .foregroundStyle(appModel.activation.isAuthorized ? Color.green : Color.orange)
            if let credentials = appModel.activation.credentials {
                LabeledContent("到期时间", value: appModel.activation.expiryText)
                    .font(.subheadline)
                Text("服务器时区：\(credentials.timezone)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(appModel.activation.phase.guidance)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("activation.summary")
    }
}

struct ActivationView: View {
    @Environment(AppModel.self) private var appModel
    @State private var code = ""
    @State private var isConfirmingReplacement = false
    @State private var isShowingSuccess = false
    @State private var isShowingContact = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        Form {
            Section("设备授权") {
                ActivationSummaryView()
                    .padding(.vertical, 6)
                if appModel.activation.hasCredentials {
                    LabeledContent("当前激活码", value: appModel.activation.maskedCode)
                    Button {
                        Task { _ = await appModel.activation.refresh() }
                    } label: {
                        HStack {
                            Text("刷新激活状态")
                            Spacer()
                            if appModel.activation.isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(appModel.activation.isRefreshing || appModel.activation.isActivating)
                }
            }

            Section {
                TextField("请输入激活码", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(.oneTimeCode)
                    .focused($isCodeFocused)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .accessibilityIdentifier("activation.code")
                    .disabled(appModel.activation.isActivating)

                Button(action: submit) {
                    HStack {
                        Text(appModel.activation.hasCredentials ? "使用新激活码" : "激活当前设备")
                        Spacer()
                        if appModel.activation.isActivating { ProgressView() }
                    }
                }
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appModel.activation.isActivating)
                .accessibilityIdentifier("activation.submit")

                if let error = appModel.activation.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("activation.error")
                }
            } header: {
                Text(appModel.activation.hasCredentials ? "更换激活码" : "填写激活码")
            } footer: {
                Text("激活码只能激活一次，从首次激活开始计时。更换设备需要新码；")
            }

            Section("续费") {
                Button("联系管理员续费") { isShowingContact = true }
                Text("管理员修改当前激活码的到期时间后，刷新激活状态即可恢复使用，无需换码。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("激活及在线验证会向授权服务器发送激活码或授权令牌及随机设备标识，不发送配对记录或定位坐标。断网时不能切换位置，当前模拟位置会保持不变；恢复真实定位始终可用。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("激活与续费")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("更换当前激活码？", isPresented: $isConfirmingReplacement, titleVisibility: .visible) {
            Button("确认使用新码") { redeem() }
        } message: {
            Text("新码激活成功后替换当前码，原剩余时间不会叠加。续费只需联系管理员修改当前码的到期时间。")
        }
        .alert("激活成功", isPresented: $isShowingSuccess) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("到期时间：\(appModel.activation.expiryText)\n服务器时区：\(appModel.activation.credentials?.timezone ?? "")")
        }
        .alert("联系管理员", isPresented: $isShowingContact) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("\(appModel.activation.renewalContact)\n当前激活码：\(appModel.activation.credentials?.code ?? "未激活")")
        }
    }

    private func submit() {
        guard !appModel.activation.isActivating, !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isCodeFocused = false
        if appModel.activation.hasCredentials { isConfirmingReplacement = true }
        else { redeem() }
    }

    private func redeem() {
        Task {
            if await appModel.activation.activate(code: code) {
                code = ""
                isShowingSuccess = true
            }
        }
    }
}
