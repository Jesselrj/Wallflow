// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Wallflow",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Wallflow",
            resources: [
                .copy("Examples")
            ]
        )
    ]
)
