import Foundation

func writeText(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = contents.data(using: .utf8) else {
        throw TestFailure(message: "unable to encode text")
    }
    try data.write(to: url, options: .atomic)
}

func loadJSONObject(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
        throw TestFailure(message: "expected JSON object at \(url.path)")
    }
    return dictionary
}

func makeTemporaryAppPaths() throws -> AppPaths {
    let paths = AppPaths(rootURL: try makeTemporaryDirectory())
    try paths.ensureDirectories()
    return paths
}
