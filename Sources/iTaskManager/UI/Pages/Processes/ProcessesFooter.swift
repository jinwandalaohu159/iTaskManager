import SwiftUI

/// Totals and the permission note under the table.
struct ProcessesFooter: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let tree = monitor.processes.tree
        HStack(spacing: 14) {
            InlineStats(items: [
                .init(label: "", value: "\(tree.processCount) 个进程", template: "0000 个进程"),
                .init(label: "CPU", value: Fmt.percent(monitor.cpu?.total ?? 0), template: Fmt.percentTemplate),
                .init(label: "内存", value: Fmt.bytes(monitor.memory?.used ?? 0), template: Fmt.bytesTemplate),
            ])
            Spacer()
            if tree.restrictedCount > 0 && !monitor.helper.isOn {
                Label(
                    monitor.settings.hideRestrictedProcesses
                        ? "已隐藏 \(tree.restrictedCount) 个需要管理员权限才能读取的系统进程"
                        : "\(tree.restrictedCount) 个系统进程的占用需要管理员权限才能读取",
                    systemImage: "lock"
                )
                .foregroundStyle(.secondary)
                if monitor.helper.state != .on && monitor.helper.state != .unavailable {
                    Button("授权读取") { monitor.helper.requestAccess() }
                        .buttonStyle(.link)
                }
            }
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
