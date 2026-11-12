import AppKit

/// 播放某个场景；`onImageChanged(nil)` 表示不演了，视图回到平时的画面。
/// 一个场景有几种演法时（见 `PetWorkScenes.variants`），开演时抽一种，演完这一段都是它。
/// 只放一遍的场景放完后报 `onFinished`；带「抛起来」的场景到那一拍报 `onHop`
final class PetWorkScenePlayer {
    var onImageChanged: ((NSImage?) -> Void)?
    var onHop: ((PetSceneHop) -> Void)?
    var onFinished: ((PetScene) -> Void)?
    private(set) var scene: PetScene?
    /// 这一段抽到的演法
    private(set) var variant: PetSceneVariant?
    private(set) var image: NSImage?
    private(set) var scenes: PetWorkScenes?
    private let now: () -> TimeInterval
    private let startsTimer: Bool
    /// 从几种演法里挑一种（测试里固定）
    private let pickVariant: ([PetSceneVariant]) -> PetSceneVariant?
    private var startedAt: TimeInterval = 0
    private var shownFrame: String?
    /// 开始演 / 换装之后报过画面没有
    private var hasReported = false
    private var hasHopped = false
    private var timer: Timer?

    var activity: AgentActivity? { scene?.activity }

    /// 侧身演（可以转头看鼠标）：没在演、或者这种演法标了侧身、或者场景本来就是侧身的
    var facesSideways: Bool {
        guard let scene else { return true }
        if let variant, scenes?.isSide(variant) == true { return true }
        return scene.facesSideways
    }

    /// 这一段要边演边把窗口左右来回挪（追球）
    var chases: Bool {
        guard let variant else { return false }
        return scenes?.chases(variant) == true
    }

    init(
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        startsTimer: Bool = true,
        pickVariant: @escaping ([PetSceneVariant]) -> PetSceneVariant? = { $0.randomElement() }
    ) {
        self.now = now
        self.startsTimer = startsTimer
        self.pickVariant = pickVariant
    }

    deinit {
        timer?.invalidate()
    }

    /// 换装后换一套帧，正在演的接着演（抽到的演法新的一套没有就重新抽）
    func reload(scenes: PetWorkScenes?) {
        self.scenes = scenes
        if let scene, let variant, scenes?.variants(for: scene).contains(variant) != true {
            self.variant = chooseVariant(for: scene)
        }
        shownFrame = nil
        hasReported = false
        showCurrentFrame()
        if scene != nil && timer == nil {
            startTimer()
        }
    }

    /// 演 `next`；`preferring` 指定演法（比如往回跑的路上接着放追球），不给就抽一种
    func play(_ next: PetScene?, preferring preferred: String? = nil) {
        guard next != scene else { return }
        scene = next
        variant = next.map { scene in
            preferred.map { PetSceneVariant(scene: scene, name: $0) } ?? chooseVariant(for: scene)
        }
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

    /// 抽一种演法；没有素材的另几种不抽（场景自己没素材时照样能抽到：就是平时的待机）
    private func chooseVariant(for scene: PetScene) -> PetSceneVariant {
        let all = scenes?.variants(for: scene) ?? [.plain(scene)]
        let playable = all.filter { !$0.isAlternative || scenes?.hasFrames($0) == true }
        return pickVariant(playable) ?? .plain(scene)
    }

    private func showCurrentFrame() {
        guard let scene, let variant else { return }
        let elapsed = now() - startedAt
        let missing = scenes?.hasFrames(variant) != true
        if (missing && scene.isOneShot) || scenes?.isFinished(variant, after: elapsed) == true {
            finish(scene)
            return
        }
        hopIfDue(variant, after: elapsed)
        let name = scenes?.frameName(variant, after: elapsed)
        // 没有这段素材时只报一次「没画面」，之后不再刷新
        guard name != shownFrame || (name == nil && image != nil) || !hasReported else { return }
        hasReported = true
        shownFrame = name
        // 没有这段素材：当作没在演，视图照常显示平时的画面
        image = scenes?.image(variant, after: elapsed)
        onImageChanged?(image)
    }

    private func hopIfDue(_ variant: PetSceneVariant, after elapsed: TimeInterval) {
        guard !hasHopped, let hop = scenes?.hop(variant), elapsed >= hop.startsAfter else { return }
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
        guard startsTimer, let variant, let scenes, scenes.hasFrames(variant) else { return }
        let fps = scenes.framesPerSecond(variant)
        let timer = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
