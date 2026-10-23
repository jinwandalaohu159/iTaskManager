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
                    Label(L("已开启"), systemImage: "checkmark.circle.fill").foregroundStyle(Palette.good)
                    Button(L("关闭", context: "switch")) {
                        helper.turnOff()
                        monitor.restart()
                    }
                case .awaitingApproval:
                    Text(L("等待在系统设置中打开")).foregroundStyle(.secondary)
                    Button(L("打开系统设置")) { helper.requestAccess() }
                case .off:
                    Text(L("未开启")).foregroundStyle(.secondary)
                    Button(L("授权…")) { helper.requestAccess() }
                case .unavailable:
                    Text(L("此版本不包含读取助手")).foregroundStyle(.secondary)
                }
            }
        } label: {
            Text(L("读取系统进程"))
                .info(L("WindowServer 等系统和其他用户的进程，需要授权后才能读取 CPU、内存和功耗。授权后由一个只读的小助手读取，只在需要时运行。"))
        }
        .onChange(of: helper.state) { _, now in
            if now == .on { monitor.restart() }
        }
    }
}
