// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Nodge",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Nodge",
            path: "Sources/Nodge",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "NodgeTests", dependencies: ["Nodge"]),
    ]
)
