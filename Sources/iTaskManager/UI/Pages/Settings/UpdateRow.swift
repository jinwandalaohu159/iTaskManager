import SwiftUI

/// The running version, and checking for or starting an update.
struct UpdateRow: View {
    @Environment(Updater.self) private var updater
    @Environment(\.smoothMotion) private var smooth

    var body: some View {
        LabeledContent("版本") {
            HStack(spacing: 10) {
                Text(AppVersion.current.description).monospacedDigit()
                if let release = updater.available {
                    Button("更新到 \(release.version.description)") { updater.presentsSheet = true }
                        .buttonStyle(.borderedProminent)
                } else {
                    // A fixed-width slot: the spinner and "已是最新" swap in place, so nothing
                    // to their left shifts while checking.
                    status
                        .frame(width: Self.statusWidth, alignment: .trailing)
                        .animation(smooth ? .easeInOut(duration: 0.2) : nil, value: updater.phase)
                    Button("检查更新") { Task { await updater.check() } }
                        .disabled(updater.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch updater.phase {
        case .checking:
            ProgressView().controlSize(.small).transition(.opacity)
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Palette.warning)
                .help(message)
                .transition(.opacity)
        default:
            if updater.lastChecked != nil {
                Text("已是最新").foregroundStyle(.secondary).transition(.opacity)
            }
        }
    }

    private static let statusWidth: CGFloat = 64
}
