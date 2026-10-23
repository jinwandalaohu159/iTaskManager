import SwiftUI

/// The running version, and checking for or starting an update.
struct UpdateRow: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        LabeledContent("版本") {
            HStack(spacing: 10) {
                Text(AppVersion.current.description).monospacedDigit()
                if let release = updater.available {
                    Button("更新到 \(release.version.description)") { updater.presentsSheet = true }
                        .buttonStyle(.borderedProminent)
                } else {
                    switch updater.phase {
                    case .checking:
                        ProgressView().controlSize(.small)
                    case .failed(let message):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.warning)
                            .help(message)
                    default:
                        if updater.lastChecked != nil {
                            Text("已是最新").foregroundStyle(.secondary)
                        }
                    }
                    Button("检查更新") { Task { await updater.check() } }
                        .disabled(updater.isBusy)
                }
            }
        }
    }
}
