// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "OptionTab",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "OptionTab", path: "Sources/OptionTab")
    ],
    swiftLanguageModes: [.v5]
)
