import AppKit

/// Agent 干活时的小场景：`<pet>/work/` 下的关键帧 + `scenes.json`（像素管线生成）。
///
/// ```json
/// { "fps": 4, "scenes": { "read": { "frames": ["read_0.png", …], "order": [0, 0, 1, …] } } }
/// ```
/// `order` 是关键帧下标，按 fps 一拍一个，放完从头循环。场景名就是 `AgentActivity` 的 rawValue。
/// 场景可以有自己的 `fps`；`"motion": "chase"` 表示边演边把窗口左右来回挪（搜索时追球）。
final class PetWorkScenes {
    private struct Manifest: Decodable {
        struct Scene: Decodable {
            let frames: [String]
            let order: [Int]
            let fps: Double?
            let motion: String?
        }

        let fps: Double
        let scenes: [String: Scene]
    }

    private let defaultFramesPerSecond: Double
    private let scenes: [String: Manifest.Scene]
    private let sprites: PetPoseSprites

    init?(directory: URL?, canvasPointSize: NSSize, fileManager: FileManager = .default) {
        guard let directory else { return nil }
        let manifestURL = directory.appendingPathComponent("scenes.json", isDirectory: false)
        guard fileManager.fileExists(atPath: manifestURL.path) else { return nil }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
            guard manifest.fps > 0 else { return nil }
            defaultFramesPerSecond = manifest.fps
            scenes = manifest.scenes
        } catch {
            NSLog("[PetWorkScenes] could not read \(manifestURL.path): \(error.localizedDescription)")
            return nil
        }
        sprites = PetPoseSprites(directory: directory, canvasPointSize: canvasPointSize, fileManager: fileManager)
    }

    /// 这只宠物有没有这个场景的素材（「在想事情」没有，就用平时的待机）
    func hasScene(for activity: AgentActivity) -> Bool {
        scenes[activity.rawValue]?.order.isEmpty == false
    }

    func framesPerSecond(for activity: AgentActivity) -> Double {
        guard let fps = scenes[activity.rawValue]?.fps, fps > 0 else { return defaultFramesPerSecond }
        return fps
    }

    /// 这个场景要不要边演边把窗口左右来回挪
    func chases(_ activity: AgentActivity) -> Bool {
        scenes[activity.rawValue]?.motion == "chase"
    }

    /// 开始演 `elapsed` 秒后该显示的帧名；这只宠物没有这个场景、或者顺序里的下标不对时为 nil
    func frameName(for activity: AgentActivity, after elapsed: TimeInterval) -> String? {
        guard let scene = scenes[activity.rawValue], !scene.order.isEmpty else { return nil }
        let beat = Int((max(0, elapsed) * framesPerSecond(for: activity)).rounded(.down)) % scene.order.count
        let index = scene.order[beat]
        return scene.frames.indices.contains(index) ? scene.frames[index] : nil
    }

    func image(for activity: AgentActivity, after elapsed: TimeInterval) -> NSImage? {
        frameName(for: activity, after: elapsed).flatMap(sprites.image(named:))
    }
}

/// 循环播放某个干活场景；`onImageChanged(nil)` 表示不演了，视图回到平时的画面
final class PetWorkScenePlayer {
    var onImageChanged: ((NSImage?) -> Void)?
    private(set) var activity: AgentActivity?
    private(set) var image: NSImage?
    private(set) var scenes: PetWorkScenes?
    private let now: () -> TimeInterval
    private let startsTimer: Bool
    private var startedAt: TimeInterval = 0
    private var shownFrame: String?
    /// 开始演 / 换装之后报过画面没有
    private var hasReported = false
    private var timer: Timer?

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, startsTimer: Bool = true) {
        self.now = now
        self.startsTimer = startsTimer
    }

    deinit {
        timer?.invalidate()
    }

    /// 换装后换一套帧，正在演的接着演
    func reload(scenes: PetWorkScenes?) {
        self.scenes = scenes
        shownFrame = nil
        hasReported = false
        showCurrentFrame()
        if activity != nil && timer == nil {
            startTimer()
        }
    }

    func play(_ next: AgentActivity?) {
        guard next != activity else { return }
        activity = next
        startedAt = now()
        shownFrame = nil
        hasReported = false
        timer?.invalidate()
        timer = nil
        guard next != nil else {
            image = nil
            onImageChanged?(nil)
            return
        }
        showCurrentFrame()
        startTimer()
    }

    func tick() {
        showCurrentFrame()
    }

    private func showCurrentFrame() {
        guard let activity else { return }
        let elapsed = now() - startedAt
        let name = scenes?.frameName(for: activity, after: elapsed)
        // 没有这段素材时只报一次「没画面」，之后不再刷新
        guard name != shownFrame || (name == nil && image != nil) || !hasReported else { return }
        hasReported = true
        shownFrame = name
        // 没有这段素材：当作没在演，视图照常显示平时的画面
        image = scenes?.image(for: activity, after: elapsed)
        onImageChanged?(image)
    }

    private func startTimer() {
        guard startsTimer, let activity, let scenes, scenes.hasScene(for: activity) else { return }
        let fps = scenes.framesPerSecond(for: activity)
        let timer = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
