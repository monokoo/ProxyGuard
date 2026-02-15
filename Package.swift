// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProxyGuard",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ProxyGuard",
            path: "Sources/ProxyGuard",
            exclude: ["Resources/Info.plist", "Resources/AppIcon.icns"],
            resources: [
                .copy("Resources/clash_verge_logo.png"),
            ],
            linkerSettings: [
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
