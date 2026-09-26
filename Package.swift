// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "KeyboardBacklight",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "KeyboardBacklight", path: "Sources/KeyboardBacklight")
    ]
)
