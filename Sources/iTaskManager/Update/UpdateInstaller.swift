import AppKit
import CryptoKit
import Foundation

/// Downloads a release, checks it, puts it in place of the running app and relaunches.
/// Nothing touches the installed app until the new one has been downloaded, verified and
/// unpacked next to it, and the swap itself rolls back if it fails halfway.
enum UpdateInstaller {
    enum Failure: LocalizedError {
        case checksumMismatch, badArchive, wrongApp, notWritable(String), swapFailed

        var errorDescription: String? {
            switch self {
            case .checksumMismatch: L("下载的文件校验失败，可能已损坏，请重试。")
            case .badArchive: L("安装包无法解压。")
            case .wrongApp: L("安装包里的应用与当前应用不符。")
            case .notWritable(let folder): L("没有权限写入“\(folder)”，请把 iTaskManager 放到“应用程序”文件夹后再更新。")
            case .swapFailed: L("无法启动安装。")
            }
        }
    }

    /// Everything up to the swap: the returned bundle sits on the same volume as the running
    /// app, ready to be moved into its place.
    static func prepare(_ release: Release, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let current = Bundle.main.bundleURL
        let folder = current.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw Failure.notWritable(folder.lastPathComponent)
        }
        // A scratch folder on the app's own volume, so the final move is a rename.
        let work = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: current, create: true
        )

        let archive = work.appending(path: release.archive.lastPathComponent)
        try await download(release.archive, to: archive, expectedSize: release.archiveSize, progress: progress)
        try Task.checkCancellation()
        if let checksum = release.checksum {
            try await verify(archive, against: checksum)
        }

        let unpacked = work.appending(path: "unpacked")
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, unpacked.path], failure: .badArchive)
        let app = unpacked.appending(path: current.lastPathComponent)
        try validate(app, as: release.version)
        return app
    }

    /// Quits, swaps the bundles and opens the new one. A small shell script does the swap
    /// once this process has exited, since a running app can't replace itself.
    @MainActor
    /// `inBackground`: start the new version without its window or taking focus.
    static func swapAndRelaunch(with app: URL, inBackground: Bool = false) throws {
        let current = Bundle.main.bundleURL
        let backup = app.deletingLastPathComponent().appending(path: "previous.app")
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.1; done
        if mv "$2" "$4" && mv "$3" "$2"; then
            rm -rf "$4"
        else
            [ -e "$2" ] || mv "$4" "$2"
        fi
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        if [ "$5" = background ]; then open -g "$2" --args \(LaunchOptions.background); else open "$2"; fi
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "swap", String(getpid()), current.path, app.path, backup.path,
                             inBackground ? "background" : "foreground"]
        do { try process.run() } catch { throw Failure.swapFailed }
        NSApplication.shared.terminate(nil)
        // terminate(_:) only returns when quitting was put off, as it is while a sheet (the
        // update sheet itself) is open. The new version is already in place to swap in, so
        // quit anyway; the script is waiting for this process to end.
        exit(0)
    }

    // MARK: Steps

    private static func download(_ url: URL, to destination: URL, expectedSize: Int,
                                 progress: @escaping @Sendable (Double) -> Void) async throws {
        let delegate = ProgressDelegate(expectedSize: expectedSize, report: progress)
        let (file, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.badArchive }
        try FileManager.default.moveItem(at: file, to: destination)
        progress(1)
    }

    private static func verify(_ file: URL, against checksumURL: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: checksumURL)
        let expected = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() } ?? ""
        let actual = SHA256.hash(data: try Data(contentsOf: file, options: .mappedIfSafe))
            .map { String(format: "%02x", $0) }.joined()
        guard !expected.isEmpty, expected == actual else { throw Failure.checksumMismatch }
    }

    private static func validate(_ app: URL, as version: AppVersion) throws {
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let shipped = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(AppVersion.init),
              shipped == version
        else { throw Failure.wrongApp }
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path], failure: .wrongApp)
    }

    private static func run(_ tool: String, _ arguments: [String], failure: Failure) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw failure }
    }

    private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        let expectedSize: Int
        let report: @Sendable (Double) -> Void

        init(expectedSize: Int, report: @escaping @Sendable (Double) -> Void) {
            self.expectedSize = expectedSize
            self.report = report
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : Int64(expectedSize)
            if total > 0 { report(min(Double(totalBytesWritten) / Double(total), 1)) }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    }
}
