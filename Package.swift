// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CupWake",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CupWake", targets: ["CupWake"])],
    targets: [
        .executableTarget(name: "CupWake"),
        .testTarget(name: "CupWakeTests", dependencies: ["CupWake"])
    ]
)
