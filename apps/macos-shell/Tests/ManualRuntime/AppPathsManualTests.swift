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
    let bundleResourcesURL = URL(fileURLWithPath: "/tmp/ICU.app/Contents/Resources", isDirectory: true)
    let lines = RuntimeLaunchDiagnostics.lines(
        appPaths: appPaths,
        repoRootURL: bundleResourcesURL.appendingPathComponent("repo", isDirectory: true),
        bundleResourceURL: bundleResourcesURL
    )

    try expect(
        lines.contains { $0.contains("[app_paths] app_support_root=/tmp/ICU") },
        "diagnostics should include app support root"
    )
    try expect(
        lines.contains { $0.contains("[app_paths] repo_root=/tmp/ICU.app/Contents/Resources/repo") },
        "diagnostics should include repo root"
    )
    try expect(
        lines.contains { $0.contains("[app_paths] mode=bundle") },
        "diagnostics should include runtime mode"
    )
}

func testRuntimeLaunchDiagnosticsUsesRepoModeWhenRepoRootIsOutsideBundleResources() throws {
    let appPaths = AppPaths(rootURL: URL(fileURLWithPath: "/tmp/ICU", isDirectory: true))
    let lines = RuntimeLaunchDiagnostics.lines(
        appPaths: appPaths,
        repoRootURL: URL(fileURLWithPath: "/Users/me/work/icu", isDirectory: true),
        bundleResourceURL: URL(fileURLWithPath: "/tmp/ICU.app/Contents/Resources", isDirectory: true)
    )

    try expect(
        lines.contains { $0.contains("[app_paths] mode=repo") },
        "diagnostics should classify non-bundled repo roots as repo mode"
    )
}

func testRuntimeLaunchDiagnosticsEmitWritesImmediatelyToProvidedOutput() throws {
    let appPaths = AppPaths(rootURL: URL(fileURLWithPath: "/tmp/ICU", isDirectory: true))
    let bundleResourcesURL = URL(fileURLWithPath: "/tmp/ICU.app/Contents/Resources", isDirectory: true)
    let pipe = Pipe()

    RuntimeLaunchDiagnostics.emit(
        appPaths: appPaths,
        repoRootURL: bundleResourcesURL.appendingPathComponent("repo", isDirectory: true),
        bundleResourceURL: bundleResourcesURL,
        output: pipe.fileHandleForWriting
    )
    try pipe.fileHandleForWriting.close()

    let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
    let output = String(decoding: data, as: UTF8.self)

    try expect(
        output.contains("[app_paths] mode=bundle\n"),
        "emitted diagnostics should include the runtime mode line"
    )
    try expect(
        output.contains("[app_paths] app_support_root=/tmp/ICU\n"),
        "emitted diagnostics should include the app support root line"
    )
    try expect(
        output.contains("[app_paths] repo_root=/tmp/ICU.app/Contents/Resources/repo\n"),
        "emitted diagnostics should include the repo root line"
    )
}
