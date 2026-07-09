// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GasPulse",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GasPulse",
            path: "Sources/GasPulse",
            linkerSettings: [.linkedLibrary("sqlite3")]
        )
    ]
)
