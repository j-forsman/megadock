// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MegaDock",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MegaDock",
            path: "Sources/MegaDock"
        )
    ]
)
