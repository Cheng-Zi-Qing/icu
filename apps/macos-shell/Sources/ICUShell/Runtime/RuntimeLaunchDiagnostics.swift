import Foundation

struct RuntimeLaunchDiagnostics {
    static func lines(appPaths: AppPaths, repoRootURL: URL?, bundleResourceURL: URL?) -> [String] {
        [
            "[app_paths] mode=\(bundleResourceURL == nil ? "repo" : "bundle")",
            "[app_paths] app_support_root=\(appPaths.rootURL.path)",
            "[app_paths] repo_root=\(repoRootURL?.path ?? "nil")",
        ]
    }
}
