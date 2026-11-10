import AppKit

/// 桌宠的小场景：`<pet>/work/` 下的关键帧 + `scenes.json`（像素管线生成）。
///
/// ```json
/// { "fps": 4, "scenes": { "read": { "frames": ["read_0.png", …], "order": [0, 0, 1, …] } } }
/// ```
/// `order` 是关键帧下标，按 fps 一拍一个，放完从头循环。场景名见 `PetScene.name`。
/// 场景可以有自己的 `fps`；`"motion": "chase"` 表示边演边把窗口左右来回挪（搜索时追球）；
/// `"once": true` 只放一遍；`"hop": { "atBeat", "pixels", "beats" }` 在第几拍把整只往上抛几格、抛几拍。
final class PetWorkScenes {
    private struct Manifest: Decodable {
        struct Hop: Decodable {
            let atBeat: Int
            let pixels: Int
            let beats: Int
        }

        struct Scene: Decodable {
            let frames: [String]
            let order: [Int]
            let fps: Double?
            let motion: String?
            let once: Bool?
            let hop: Hop?
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
    func hasScene(for scene: PetScene) -> Bool {
        scenes[scene.name]?.order.isEmpty == false
    }

    func framesPerSecond(for scene: PetScene) -> Double {
        guard let fps = scenes[scene.name]?.fps, fps > 0 else { return defaultFramesPerSecond }
        return fps
    }

    /// 这个场景要不要边演边把窗口左右来回挪
    func chases(_ scene: PetScene) -> Bool {
        scenes[scene.name]?.motion == "chase"
    }

    func playsOnce(_ scene: PetScene) -> Bool {
        scenes[scene.name]?.once == true
    }

    /// 只放一遍的场景放完了没有（循环的永远放不完）。干完了 / 出错了就算 manifest 忘了写 once 也只放一遍，
    /// 不然会一直挡着打盹、后面的动作也排不上
    func isFinished(_ scene: PetScene, after elapsed: TimeInterval) -> Bool {
        guard playsOnce(scene) || scene.isOneShot, let count = scenes[scene.name]?.order.count else { return false }
        return beat(for: scene, after: elapsed) >= count
    }

    /// 这个场景在第几拍往上抛、抛多高多久；没有就是 nil
    func hop(for scene: PetScene) -> PetSceneHop? {
        guard let hop = scenes[scene.name]?.hop, hop.pixels > 0, hop.beats > 0 else { return nil }
        let beat = 1 / framesPerSecond(for: scene)
        return PetSceneHop(startsAfter: Double(hop.atBeat) * beat, pixels: hop.pixels, duration: Double(hop.beats) * beat)
    }

    /// 开始演 `elapsed` 秒后该显示的帧名；没有这个场景、只放一遍的已经放完、或者顺序里的下标不对时为 nil
    func frameName(for scene: PetScene, after elapsed: TimeInterval) -> String? {
        guard let entry = scenes[scene.name], !entry.order.isEmpty, !isFinished(scene, after: elapsed) else { return nil }
        let index = entry.order[beat(for: scene, after: elapsed) % entry.order.count]
        return entry.frames.indices.contains(index) ? entry.frames[index] : nil
    }

    func image(for scene: PetScene, after elapsed: TimeInterval) -> NSImage? {
        frameName(for: scene, after: elapsed).flatMap(sprites.image(named:))
    }

    private func beat(for scene: PetScene, after elapsed: TimeInterval) -> Int {
        Int((max(0, elapsed) * framesPerSecond(for: scene)).rounded(.down))
    }
}

/// 播放某个场景；`onImageChanged(nil)` 表示不演了，视图回到平时的画面。
/// 只放一遍的场景放完后报 `onFinished`；带「抛起来」的场景到那一拍报 `onHop`
final class PetWorkScenePlayer {
    var onImageChanged: ((NSImage?) -> Void)?
    var onHop: ((PetSceneHop) -> Void)?
    var onFinished: ((PetScene) -> Void)?
    private(set) var scene: PetScene?
    private(set) var image: NSImage?
    private(set) var scenes: PetWorkScenes?
    private let now: () -> TimeInterval
    private let startsTimer: Bool
    private var startedAt: TimeInterval = 0
    private var shownFrame: String?
    /// 开始演 / 换装之后报过画面没有
    private var hasReported = false
    private var hasHopped = false
    private var timer: Timer?

    var activity: AgentActivity? { scene?.activity }

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
        if scene != nil && timer == nil {
            startTimer()
        }
    }

    func play(_ next: PetScene?) {
        guard next != scene else { return }
        scene = next
        startedAt = now()
        shownFrame = nil
        hasReported = false
        hasHopped = false
        timer?.invalidate()
        timer = nil
        guard next != nil else {
            image = nil
            onImageChanged?(nil)
            return
        }
        showCurrentFrame()
        // 第一帧就放完了的话，onFinished 里可能已经换了下一段（还开了它的计时器）
        guard scene == next else { return }
        startTimer()
    }

    func tick() {
        showCurrentFrame()
    }

    /// 测试用：当作这一段已经放完
    func finishForTesting() {
        guard let scene else { return }
        finish(scene)
    }

    private func showCurrentFrame() {
        guard let scene else { return }
        let elapsed = now() - startedAt
        let missing = scenes?.hasScene(for: scene) != true
        if (missing && scene.isOneShot) || scenes?.isFinished(scene, after: elapsed) == true {
            finish(scene)
            return
        }
        hopIfDue(scene, after: elapsed)
        let name = scenes?.frameName(for: scene, after: elapsed)
        // 没有这段素材时只报一次「没画面」，之后不再刷新
        guard name != shownFrame || (name == nil && image != nil) || !hasReported else { return }
        hasReported = true
        shownFrame = name
        // 没有这段素材：当作没在演，视图照常显示平时的画面
        image = scenes?.image(for: scene, after: elapsed)
        onImageChanged?(image)
    }

    private func hopIfDue(_ scene: PetScene, after elapsed: TimeInterval) {
        guard !hasHopped, let hop = scenes?.hop(for: scene), elapsed >= hop.startsAfter else { return }
        hasHopped = true
        onHop?(hop)
    }

    private func finish(_ finished: PetScene) {
        play(nil)
        onFinished?(finished)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = nil
        guard startsTimer, let scene, let scenes, scenes.hasScene(for: scene) else { return }
        let fps = scenes.framesPerSecond(for: scene)
        let timer = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
