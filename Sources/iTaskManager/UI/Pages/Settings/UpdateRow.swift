import SwiftUI

/// The running version with the update status under it, and the one action that fits the
/// status on the right. The status line is always there, so checking only changes its text.
struct UpdateRow: View {
    @Environment(Updater.self) private var updater
    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        // Not LabeledContent: that lines the button up with the first line of text, where it
        // should sit centred beside both.
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("iTaskManager \(AppVersion.current.description)")
                status
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(smooth ? .easeInOut(duration: 0.2) : nil, value: updater.phase)
            }
            Spacer(minLength: 12)
            if let release = updater.available {
                Button(L("更新到 \(release.version.description)")) { updater.presentsSheet = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(L("检查更新")) { Task { await updater.check() } }
                    .disabled(updater.isBusy)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let release = updater.available, !updater.isBusy {
            Text(L("有新版本 \(release.version.description) 可用"))
        } else {
            switch updater.phase {
            case .checking:
                Text(L("正在检查更新…"))
            case .downloading(let fraction):
                Text(L("正在下载 \(Fmt.percent(fraction))"))
            case .installing:
                Text(L("正在安装…"))
            case .failed(let message):
                Label(L("检查失败"), systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.titleAndIcon)
                    .help(message)
            case .idle:
                if let checked = updater.lastChecked {
                    Text(L("已是最新版本 · 上次检查 \(checked.formatted(.dateTime.hour().minute().locale(Localizer.shared.language.locale)))"))
                } else {
                    Text(L("尚未检查更新"))
                }
            }
        }
    }
}
