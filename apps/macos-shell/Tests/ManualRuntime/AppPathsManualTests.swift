import Foundation

func testAppPathsLivePrefersICUAppSupportRootOverride() throws {
    let root = try makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }

    let paths = try AppPaths.live(
        environment: ["ICU_APP_SUPPORT_ROOT": root.path],
        fileManager: .default
    )

    try expect(
        paths.rootURL.standardizedFileURL == root.standardizedFileURL,
        "live paths should honor ICU_APP_SUPPORT_ROOT"
    )
}

func testRuntimeLaunchDiagnosticsIncludeBundleAndAppSupportPaths() throws {
    let appPaths = AppPaths(rootURL: URL(fileURLWithPath: "/tmp/ICU", isDirectory: true))
    let lines = RuntimeLaunchDiagnostics.lines(
        appPaths: appPaths,
        repoRootURL: URL(fileURLWithPath: "/tmp/repo", isDirectory: true),
        bundleResourceURL: URL(fileURLWithPath: "/tmp/ICU.app/Contents/Resources", isDirectory: true)
    )

    try expect(
        lines.contains { $0.contains("[app_paths] app_support_root=/tmp/ICU") },
        "diagnostics should include app support root"
    )
    try expect(
        lines.contains { $0.contains("[app_paths] repo_root=/tmp/repo") },
        "diagnostics should include repo root"
    )
    try expect(
        lines.contains { $0.contains("[app_paths] mode=bundle") },
        "diagnostics should include runtime mode"
    )
}
