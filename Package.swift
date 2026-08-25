// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MacKards",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "MacKards",
            path: "MacKards",
            exclude: ["Info.plist"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-Osize"])
            ]
        )
    ]
)
