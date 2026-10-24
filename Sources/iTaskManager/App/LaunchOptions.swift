import Foundation

/// How this launch was asked for.
enum LaunchOptions {
    /// Restarted after a quiet update: stay in the menu bar, as the previous copy was.
    static let background = "--background"

    static let startedInBackground = CommandLine.arguments.contains(background)
}
