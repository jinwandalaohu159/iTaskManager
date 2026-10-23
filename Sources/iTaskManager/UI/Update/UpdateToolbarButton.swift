import SwiftUI

/// "更新到 1.1" in the main window's toolbar while a newer version is out.
struct UpdateToolbarButton: View {
    @Environment(Updater.self) private var updater

    var body: some View {
        if let release = updater.available {
            Button {
                updater.presentsSheet = true
            } label: {
                Label("更新到 \(release.version.description)", systemImage: "arrow.down.circle.fill")
                    .labelStyle(.titleAndIcon)
            }
            .tint(.accentColor)
            .help("下载并安装 iTaskManager \(release.version.description)，完成后自动重新启动")
        }
    }
}
