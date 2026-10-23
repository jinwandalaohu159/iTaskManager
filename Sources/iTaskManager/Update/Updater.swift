import Foundation
import Observation

/// Looks for new releases on GitHub and installs one in a single step: download with
/// progress, verify, swap, relaunch.
@MainActor
@Observable
final class Updater {
    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Double)
        case installing
        case failed(String)
    }

    /// A newer version than this one, once found.
    private(set) var available: Release?
    private(set) var phase = Phase.idle
    private(set) var lastChecked: Date?
    /// Set to bring up the update sheet in the main window, e.g. from the menu bar panel.
    var presentsSheet = false

    @ObservationIgnored private var schedule: Task<Void, Never>?
    @ObservationIgnored private var installation: Task<Void, Never>?

    static let checkInterval: Duration = .seconds(6 * 3600)

    /// Checks shortly after launch and then every few hours, while `enabled` says so.
    func startAutomaticChecks(enabled: @escaping @MainActor () -> Bool) {
        schedule?.cancel()
        schedule = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            while !Task.isCancelled {
                if enabled() { await self?.check() }
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .installing: true
        default: false
        }
    }

    func check() async {
        guard !isBusy else { return }
        phase = .checking
        do {
            let latest = try await GitHubReleases.latest()
            available = latest.version > AppVersion.current ? latest : nil
            phase = .idle
            if available != nil, DevHooks.installUpdateWhenFound { presentsSheet = true }
        } catch GitHubReleases.Failure.noRelease {
            available = nil
            phase = .idle
        } catch {
            phase = .failed(L("检查更新失败：\(error.localizedDescription)"))
        }
        lastChecked = .now
    }

    func install() {
        guard let release = available, !isBusy else { return }
        phase = .downloading(0)
        let report: @Sendable (Double) -> Void = { [weak self] fraction in
            Task { @MainActor in self?.downloaded(fraction) }
        }
        installation = Task { [weak self] in
            do {
                let app = try await UpdateInstaller.prepare(release, progress: report)
                guard let self, !Task.isCancelled else { return }
                self.phase = .installing
                // Let the "installing" state render before the app quits.
                try await Task.sleep(for: .milliseconds(400))
                try UpdateInstaller.swapAndRelaunch(with: app)
            } catch is CancellationError {
                self?.phase = .idle
            } catch {
                if (error as? URLError)?.code == .cancelled {
                    self?.phase = .idle
                } else {
                    self?.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func downloaded(_ fraction: Double) {
        guard case .downloading = phase else { return }
        phase = .downloading(fraction)
    }

    func cancel() {
        installation?.cancel()
        installation = nil
        phase = .idle
    }

    func dismissFailure() {
        if case .failed = phase { phase = .idle }
    }
}
