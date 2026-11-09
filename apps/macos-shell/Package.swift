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
        ),
        // Claude Code 钩子：把会话状态写成文件给桌宠读
        .executable(
            name: "icu-hook",
            targets: ["ICUHook"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ICUShell",
            path: "Sources/ICUShell"
        ),
        .executableTarget(
            name: "ICUHook",
            path: "Sources/ICUHook"
        ),
        .testTarget(
            name: "ICUShellTests",
            dependencies: ["ICUShell"],
            path: "Tests/ICUShellTests"
        ),
    ]
)
