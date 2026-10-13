// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppStoreConnect",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "asc", targets: ["asc"]),
        .library(name: "ASCKit", targets: ["ASCKit"]),
    ],
    targets: [
        .target(name: "ASCKit"),
        .executableTarget(name: "asc", dependencies: ["ASCKit"]),
        .testTarget(name: "ASCKitTests", dependencies: ["ASCKit"]),
    ]
)
