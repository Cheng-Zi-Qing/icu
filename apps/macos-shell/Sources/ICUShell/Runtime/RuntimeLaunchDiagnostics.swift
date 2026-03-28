import Foundation

struct RuntimeLaunchDiagnostics {
    static func lines(appPaths: AppPaths, repoRootURL: URL?, bundleResourceURL: URL?) -> [String] {
        let mode = runtimeMode(repoRootURL: repoRootURL, bundleResourceURL: bundleResourceURL)
        return [
            "[app_paths] mode=\(mode)",
            "[app_paths] app_support_root=\(appPaths.rootURL.path)",
            "[app_paths] repo_root=\(repoRootURL?.path ?? "nil")",
        ]
    }

    private static func runtimeMode(repoRootURL: URL?, bundleResourceURL: URL?) -> String {
        guard let bundleResourceURL else {
            return "repo"
        }

        guard let repoRootURL else {
            return "bundle"
        }

        let bundlePath = bundleResourceURL.standardizedFileURL.path
        let repoPath = repoRootURL.standardizedFileURL.path
        if repoPath == bundlePath || repoPath.hasPrefix(bundlePath + "/") {
            return "bundle"
        }

        return "repo"
    }
}
