// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Quota",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Quota", targets: ["QuotaApp"]),
        .library(name: "QuotaCore", targets: ["QuotaCore"])
    ],
    targets: [
        .target(name: "QuotaCore"),
        .executableTarget(name: "QuotaApp", dependencies: ["QuotaCore"]),
        .testTarget(name: "QuotaCoreTests", dependencies: ["QuotaCore"])
    ]
)
