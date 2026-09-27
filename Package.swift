// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodeField",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "CodeField", targets: ["CodeField"]),
    ],
    targets: [
        .target(name: "CodeField"),
        .testTarget(name: "CodeFieldTests", dependencies: ["CodeField"]),
    ]
)
