// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "VideoCompressor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VideoCompressor", targets: ["VideoCompressor"])
    ],
    targets: [
        .executableTarget(
            name: "VideoCompressor",
            path: "VideoCompressor",
            resources: [
                .copy("Resources/ffmpeg"),
                .copy("Resources/ffprobe"),
                .copy("Resources/AppIcon1024.png"),
                .copy("Resources/AppIcon.icns"),
                .process("Resources/zh-Hans.lproj"),
                .process("Resources/en.lproj")
            ]
        ),
        .testTarget(
            name: "VideoCompressorTests",
            dependencies: ["VideoCompressor"],
            path: "Tests/VideoCompressorTests"
        )
    ]
)
