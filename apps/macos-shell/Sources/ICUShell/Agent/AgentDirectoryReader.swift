import Foundation

/// 读 `<App Support>/ICU/agents/*.json`（icu-hook 写的，一个会话一个文件）
struct AgentDirectoryReader {
    /// 一天都没动静的会话（Claude 崩了、没发 SessionEnd）直接清掉
    static let forgetAfter: TimeInterval = 24 * 60 * 60

    let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    init(appPaths: AppPaths) {
        self.init(directory: appPaths.rootURL.appendingPathComponent("agents", isDirectory: true))
    }

    func readSessions(now: TimeInterval, fileManager: FileManager = .default) -> [AgentSession] {
        let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> AgentSession? in
                // 读不出来的先跳过：钩子可能正在写（原子写入一般不会，但别因此删掉）
                guard
                    let data = try? Data(contentsOf: url),
                    let session = AgentSession(record: try? JSONSerialization.jsonObject(with: data))
                else {
                    return nil
                }
                guard now - session.updatedAt <= Self.forgetAfter else {
                    try? fileManager.removeItem(at: url)
                    return nil
                }
                return session
            }
            .sorted { $0.id < $1.id }
    }
}
