// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OilMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OilMonitor",
            path: "Sources/OilMonitor",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
