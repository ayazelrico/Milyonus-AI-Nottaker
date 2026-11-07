// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MilyonusNottaker",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Shared", targets: ["Shared"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Authentication", targets: ["Authentication"]),
        .library(name: "AudioCapture", targets: ["AudioCapture"]),
        .library(name: "Permissions", targets: ["Permissions"]),
        .library(name: "Transcription", targets: ["Transcription"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .executable(name: "MilyonusApp", targets: ["MilyonusApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.3"),
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.12.0"),
    ],
    targets: [
        .target(
            name: "Shared",
            exclude: ["Resources/Localizable.xcstrings"],
            resources: [.process("Resources")]
        ),
        .target(name: "DesignSystem", dependencies: ["Shared"], resources: [.process("Resources")]),
        .target(
            name: "Authentication",
            dependencies: ["Shared", .product(name: "Auth", package: "supabase-swift")]
        ),
        .target(
            name: "AudioCapture",
            dependencies: ["Shared"],
            resources: [.process("Resources")]
        ),
        .target(name: "Permissions", dependencies: ["Shared"]),
        .target(name: "Transcription", dependencies: ["Shared"]),
        .target(
            name: "Persistence",
            dependencies: ["Shared", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .executableTarget(
            name: "MilyonusApp",
            dependencies: ["Shared", "DesignSystem", "Authentication", "AudioCapture", "Permissions"]
        ),
        .testTarget(name: "SharedTests", dependencies: ["Shared"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(
            name: "AuthenticationTests",
            dependencies: ["Authentication", "Shared", .product(name: "Auth", package: "supabase-swift")]
        ),
        .testTarget(name: "AudioCaptureTests", dependencies: ["AudioCapture", "Shared"]),
        .testTarget(name: "PermissionsTests", dependencies: ["Permissions", "Shared"]),
        .testTarget(name: "TranscriptionTests", dependencies: ["Transcription", "Shared"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Shared"]),
    ],
    swiftLanguageModes: [.v6]
)
