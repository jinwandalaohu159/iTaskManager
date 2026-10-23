import SwiftUI

/// Shown once at first launch: explains why reading system processes needs approval and takes
/// the user to the switch in System Settings. Closes by itself once the switch is on.
struct SystemAccessPrompt: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let state = monitor.helper.state
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(spacing: 8) {
                Text("显示所有进程的完整数据")
                    .font(.title3.weight(.semibold))
                Text("WindowServer 等约 300 个进程属于系统或其他用户，读取它们的 CPU、内存和功耗需要你的授权。授权后，iTaskManager 会使用一个只读的小助手，只在需要时运行。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                switch state {
                case .on:
                    Label("已授权", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.good)
                case .awaitingApproval:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("在系统设置中打开 iTaskManager 的开关")
                    }
                    .foregroundStyle(.secondary)
                default:
                    Text("点击“去授权”后，在系统设置里打开 iTaskManager 的开关即可。")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .frame(minHeight: 22)
            .contentTransition(.opacity)
            .animation(.smooth(duration: 0.3), value: state)

            HStack(spacing: 12) {
                Button("以后再说") { close() }
                    .keyboardShortcut(.cancelAction)
                Button(state == .awaitingApproval ? "打开系统设置" : "去授权") {
                    monitor.helper.requestAccess()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(state == .on)
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 420)
        .onChange(of: state) { _, now in
            guard now == .on else { return }
            monitor.restart()
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                close()
            }
        }
    }

    private func close() {
        settings.askedForSystemAccess = true
        dismiss()
    }
}
