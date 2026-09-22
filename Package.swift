// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Nodge",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kyinwind/MOSSTTSKit.git", exact: "0.1.15"),
    ],
    targets: [
        .executableTarget(
            name: "Nodge",
            dependencies: ["MOSSTTSKit"],
            path: "Sources/Nodge",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "NodgeTests", dependencies: ["Nodge"]),
    ]
)
