// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "AudioTranscriber",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "AudioTranscriber",
            targets: ["AudioTranscriber"]),
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "AudioTranscriber",
            dependencies: ["WhisperKit"]),
    ]
)