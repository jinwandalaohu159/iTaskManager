// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iTaskManager",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "HelperProtocol"),
        .target(
            name: "CSystem",
            dependencies: ["HelperProtocol"],
            linkerSettings: [
                .linkedLibrary("IOReport"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .executableTarget(
            name: "iTaskManager",
            dependencies: ["CSystem"]
        ),
        // Runs as root via launchd; see Sources/iTaskManagerHelper/main.c.
        .executableTarget(
            name: "iTaskManagerHelper",
            dependencies: ["HelperProtocol"]
        ),
    ]
)
