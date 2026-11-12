import AppKit

/// 桌宠的小场景：`<pet>/work/` 下的关键帧 + `scenes.json`（像素管线生成）。
///
/// ```json
/// { "fps": 4, "scenes": { "read": { "frames": ["read_0.png", …], "order": [0, 0, 1, …] } } }
/// ```
/// `order` 是关键帧下标，按 fps 一拍一个，放完从头循环。场景名见 `PetScene.name`。
/// 场景可以有自己的 `fps`；`"motion": "chase"` 表示边演边把窗口左右来回挪（搜索时追球）；
/// `"once": true` 表示只放一遍；
/// `"hop": { "atBeat", "pixels", "beats" }` 在第几拍把整只往上抛几格、抛几拍；
/// `"variantOf": "eat"` 表示它是 eat 的另一种演法（开演时在几种里抽一种）；`"side": true` 表示侧身演。
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
            let variantOf: String?
            let side: Bool?
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

    // MARK: - 几种演法

    /// 这个场景能怎么演：它自己（就算没有素材，比如「在想」就是平时的待机），加上标了 `variantOf` 的另几种
    func variants(for scene: PetScene) -> [PetSceneVariant] {
        let others = scenes.filter { $0.value.variantOf == scene.name }.keys.sorted()
        return ([scene.name] + others).map { PetSceneVariant(scene: scene, name: $0) }
    }

    /// 侧身演（可以转头看鼠标）
    func isSide(_ variant: PetSceneVariant) -> Bool {
        scenes[variant.name]?.side == true
    }

    // MARK: - 按演法查

    func hasFrames(_ variant: PetSceneVariant) -> Bool {
        scenes[variant.name]?.order.isEmpty == false
    }

    func framesPerSecond(_ variant: PetSceneVariant) -> Double {
        guard let fps = scenes[variant.name]?.fps, fps > 0 else { return defaultFramesPerSecond }
        return fps
    }

    /// 这种演法要不要边演边把窗口左右来回挪
    func chases(_ variant: PetSceneVariant) -> Bool {
        scenes[variant.name]?.motion == "chase"
    }

    /// 只放一遍的演法放完了没有（循环的永远放不完）。干完了 / 出错了就算 manifest 忘了写 once 也只放一遍，
    /// 不然会一直挡着打盹、后面的动作也排不上
    func isFinished(_ variant: PetSceneVariant, after elapsed: TimeInterval) -> Bool {
        let once = scenes[variant.name]?.once == true || variant.scene.isOneShot
        guard once, let count = scenes[variant.name]?.order.count else { return false }
        return beat(variant, after: elapsed) >= count
    }

    /// 这种演法在第几拍往上抛、抛多高多久；没有就是 nil
    func hop(_ variant: PetSceneVariant) -> PetSceneHop? {
        guard let hop = scenes[variant.name]?.hop, hop.pixels > 0, hop.beats > 0 else { return nil }
        let beat = 1 / framesPerSecond(variant)
        return PetSceneHop(startsAfter: Double(hop.atBeat) * beat, pixels: hop.pixels, duration: Double(hop.beats) * beat)
    }

    /// 开始演 `elapsed` 秒后该显示的帧名；没有素材、只放一遍的已经放完、或者顺序里的下标不对时为 nil
    func frameName(_ variant: PetSceneVariant, after elapsed: TimeInterval) -> String? {
        guard let entry = scenes[variant.name], !entry.order.isEmpty, !isFinished(variant, after: elapsed) else { return nil }
        let index = entry.order[beat(variant, after: elapsed) % entry.order.count]
        return entry.frames.indices.contains(index) ? entry.frames[index] : nil
    }

    func image(_ variant: PetSceneVariant, after elapsed: TimeInterval) -> NSImage? {
        frameName(variant, after: elapsed).flatMap(sprites.image(named:))
    }

    private func beat(_ variant: PetSceneVariant, after elapsed: TimeInterval) -> Int {
        Int((max(0, elapsed) * framesPerSecond(variant)).rounded(.down))
    }

    // MARK: - 按场景查（它自己那种演法）

    func hasScene(for scene: PetScene) -> Bool { hasFrames(.plain(scene)) }
    func framesPerSecond(for scene: PetScene) -> Double { framesPerSecond(.plain(scene)) }
    func chases(_ scene: PetScene) -> Bool { chases(.plain(scene)) }
    func playsOnce(_ scene: PetScene) -> Bool { scenes[scene.name]?.once == true }
    func isFinished(_ scene: PetScene, after elapsed: TimeInterval) -> Bool { isFinished(.plain(scene), after: elapsed) }
    func hop(for scene: PetScene) -> PetSceneHop? { hop(.plain(scene)) }
    func frameName(for scene: PetScene, after elapsed: TimeInterval) -> String? { frameName(.plain(scene), after: elapsed) }
    func image(for scene: PetScene, after elapsed: TimeInterval) -> NSImage? { image(.plain(scene), after: elapsed) }
}

/// 一个场景的某一种演法：`name` 是 scenes.json 里的场景名（它自己，或者标了 variantOf 的另一种）
struct PetSceneVariant: Equatable {
    let scene: PetScene
    let name: String

    /// 场景自己那种演法
    static func plain(_ scene: PetScene) -> PetSceneVariant {
        PetSceneVariant(scene: scene, name: scene.name)
    }

    /// 是不是另外画的那几种（不是场景自己）
    var isAlternative: Bool { name != scene.name }
}
