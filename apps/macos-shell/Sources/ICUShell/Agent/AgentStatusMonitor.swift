import AppKit

/// 盯着 agents/ 目录，算出桌宠现在该表现哪种 Agent 状态。
///
/// - 目录一有变化（icu-hook 写入 / 删除）就重读；另外每 30 秒重算一次，让超时的会话回到待机
/// - 你切到某个终端：在那里等你的会话就算交给你了，不再催
/// - 你本来就在那个终端里：提问就在眼前，也不催
@MainActor
final class AgentStatusMonitor {
    static let refreshInterval: TimeInterval = 30

    var onChange: ((AgentSummary) -> Void)?
    private(set) var board = AgentBoard(sessions: [])
    private(set) var summary = AgentSummary.idle

    private let reader: AgentDirectoryReader
    private let now: () -> TimeInterval
    private let frontmostBundleID: () -> String?
    private var directorySource: DispatchSourceFileSystemObject?
    private var refreshTimer: Timer?
    private var activationObserver: NSObjectProtocol?

    init(
        reader: AgentDirectoryReader,
        now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 },
        frontmostBundleID: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.bundleIdentifier },
        startsWatching: Bool = true
    ) {
        self.reader = reader
        self.now = now
        self.frontmostBundleID = frontmostBundleID
        if startsWatching {
            start()
        }
    }

    func reload() {
        let next = board.replacing(sessions: reader.readSessions(now: now()))
        board = frontmostBundleID().map(next.acknowledging(appBundleID:)) ?? next
        publish()
    }

    func applicationActivated(bundleID: String) {
        board = board.acknowledging(appBundleID: bundleID)
        publish()
    }

    func stop() {
        directorySource?.cancel()
        directorySource = nil
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
    }

    private func publish() {
        let next = board.summary(at: now())
        guard next != summary else { return }
        summary = next
        onChange?(next)
    }

    private func start() {
        do {
            try FileManager.default.createDirectory(at: reader.directory, withIntermediateDirectories: true)
        } catch {
            NSLog("[AgentStatus] could not create \(reader.directory.path): \(error.localizedDescription)")
        }
        watchDirectory()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let bundleID = app?.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.applicationActivated(bundleID: bundleID) }
        }
        reload()
    }

    private func watchDirectory() {
        let descriptor = open(reader.directory.path, O_EVTONLY)
        guard descriptor >= 0 else {
            NSLog("[AgentStatus] could not watch \(reader.directory.path); falling back to the \(Int(Self.refreshInterval))s refresh")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        directorySource = source
    }
}
