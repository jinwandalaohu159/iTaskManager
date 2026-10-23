import SwiftUI

/// Whether the root helper is on, and the one action that moves it forward.
struct SystemAccessRow: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let helper = monitor.helper
        LabeledContent {
            HStack(spacing: 10) {
                switch helper.state {
                case .on:
                    Label("已开启", systemImage: "checkmark.circle.fill").foregroundStyle(Palette.good)
                    Button("关闭") {
                        helper.turnOff()
                        monitor.restart()
                    }
                case .awaitingApproval:
                    Text("等待在系统设置中打开").foregroundStyle(.secondary)
                    Button("打开系统设置") { helper.requestAccess() }
                case .off:
                    Text("未开启").foregroundStyle(.secondary)
                    Button("授权…") { helper.requestAccess() }
                case .unavailable:
                    Text("此版本不包含读取助手").foregroundStyle(.secondary)
                }
            }
        } label: {
            Text("读取系统进程")
                .info("WindowServer 等系统和其他用户的进程，需要授权后才能读取 CPU、内存和功耗。授权后由一个只读的小助手读取，只在需要时运行。")
        }
        .onChange(of: helper.state) { _, now in
            if now == .on { monitor.restart() }
        }
    }
}
