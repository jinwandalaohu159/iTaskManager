import SwiftUI

/// Opened by the "更新" button: starts right away and runs through to the relaunch,
/// showing the release notes while the download progresses.
struct UpdateSheet: View {
    @Environment(Updater.self) private var updater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("iTaskManager \(updater.available?.version.description ?? "")")
                        .font(.title3.weight(.semibold))
                    Text(L("当前版本 \(AppVersion.current.description)"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if let release = updater.available, !release.notes.isEmpty {
                ScrollView {
                    Text(Self.markdown(release.notes))
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 180)
                .padding(12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            status
                .frame(minHeight: 44)

            HStack {
                if let page = updater.available?.page {
                    Link(L("在 GitHub 上查看"), destination: page).font(.callout)
                }
                Spacer()
                switch updater.phase {
                case .downloading:
                    Button(L("取消")) {
                        updater.cancel()
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                case .failed:
                    Button(L("关闭")) {
                        updater.dismissFailure()
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    Button(L("重试")) { updater.install() }
                        .keyboardShortcut(.defaultAction)
                case .installing:
                    EmptyView()
                default:
                    Button(L("关闭")) { dismiss() }
                }
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { updater.install() }
    }

    @ViewBuilder
    private var status: some View {
        switch updater.phase {
        case .downloading(let fraction):
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: fraction)
                    .animation(.linear(duration: 0.2), value: fraction)
                HStack {
                    Text(L("正在下载…"))
                    Spacer()
                    Text(Fmt.percent(fraction)).monospacedDigit()
                        .reservingWidth(of: Fmt.percentTemplate, alignment: .trailing)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(L("正在安装，即将重新启动…"))
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
    }

    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
