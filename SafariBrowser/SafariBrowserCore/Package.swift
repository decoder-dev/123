// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SafariBrowserCore",
    platforms: [.iOS(.v18_4)],
    products: [
        .library(name: "SafariBrowserCore", targets: ["SafariBrowserCore"]),
    ],
    targets: [
        .target(name: "SafariBrowserCore"),
        .testTarget(
            name: "SafariBrowserCoreTests",
            dependencies: ["SafariBrowserCore"]
        ),
    ]
)
