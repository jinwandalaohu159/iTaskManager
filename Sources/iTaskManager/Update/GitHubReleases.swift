import Foundation

/// A published version: what the update sheet shows and what the installer fetches.
struct Release: Sendable, Equatable {
    let version: AppVersion
    let title: String
    /// Release notes, in Markdown.
    let notes: String
    let page: URL
    /// The zipped app, and the file holding its SHA-256.
    let archive: URL
    let archiveSize: Int
    let checksum: URL?
}

/// Reads releases from the project's public GitHub repository.
enum GitHubReleases {
    static let repository = "jinwandalaohu159/iTaskManager"

    enum Failure: LocalizedError {
        case noRelease, unreadable, noArchive

        var errorDescription: String? {
            switch self {
            case .noRelease: L("还没有发布任何版本。")
            case .unreadable: L("无法读取版本信息。")
            case .noArchive: L("最新版本缺少安装包。")
            }
        }
    }

    /// The newest published, non-prerelease version.
    static func latest() async throws -> Release {
        let feed = DevHooks.updateFeed ?? URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: feed)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("iTaskManager/\(AppVersion.current)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 404 { throw Failure.noRelease }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let version = AppVersion(payload.tag_name),
              let page = URL(string: payload.html_url)
        else { throw Failure.unreadable }
        guard let zip = payload.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let archive = URL(string: zip.browser_download_url)
        else { throw Failure.noArchive }
        let checksum = payload.assets.first { $0.name == zip.name + ".sha256" }

        return Release(
            version: version,
            title: payload.name ?? "iTaskManager \(version)",
            notes: payload.body ?? "",
            page: page,
            archive: archive,
            archiveSize: zip.size,
            checksum: checksum.flatMap { URL(string: $0.browser_download_url) }
        )
    }

    private struct Payload: Decodable {
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: String
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
            let size: Int
        }
    }
}
