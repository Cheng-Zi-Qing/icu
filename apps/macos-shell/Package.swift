// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ICUShell",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ICUShell",
            targets: ["ICUShell"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ICUShell",
            path: "Sources/ICUShell"
        ),
        .testTarget(
            name: "ICUShellTests",
            dependencies: ["ICUShell"],
            path: "Tests/ICUShellTests"
        ),
    ]
)
