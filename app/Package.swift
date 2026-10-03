// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MilyonusNottaker",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .executable(name: "MilyonusApp", targets: ["MilyonusApp"]),
    ],
    targets: [
        .target(
            name: "Shared",
            exclude: ["Resources/Localizable.xcstrings"],
            resources: [.process("Resources")]
        ),
        .target(name: "DesignSystem", dependencies: ["Shared"], resources: [.process("Resources")]),
        .executableTarget(name: "MilyonusApp", dependencies: ["Shared", "DesignSystem"]),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ],
    swiftLanguageModes: [.v6]
)
