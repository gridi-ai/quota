// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Quota",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Quota", targets: ["QuotaApp"]),
        .library(name: "QuotaCore", targets: ["QuotaCore"])
    ],
    targets: [
        .target(name: "QuotaCore", resources: [.process("Resources")]),
        .executableTarget(name: "QuotaApp", dependencies: ["QuotaCore"], resources: [.process("Resources")]),
        .testTarget(name: "QuotaCoreTests", dependencies: ["QuotaCore"])
    ]
)
