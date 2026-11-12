import AppKit

/// 戳一下（点了没拖）：按戳到的部位放一段反应，冒一句话；吓一跳时整只蹦起来。
/// 部位划分见 PetPokeZone，戳太多下生气见 PetPokeTracker
extension DesktopPetView {
    /// 吓一跳蹦多高（素材像素）、多久落地
    static let startledHopPixels = 2
    static let startledHopDuration: CFTimeInterval = 0.3
    /// 被戳时冒的那句话停多久
    static let pokeBubbleDuration: TimeInterval = 1.8

    /// 平时坐着（休息时平时坐着也算）才有反应：探头、被拎着、Agent 干活 / 提醒小场景、头顶卡片在的时候点了只蹦一下
    var canReactToPoke: Bool {
        !isPeeking && !isDraggingPet && !isShowingDragPose && isFreeForIdleActs && waitCardView.isHidden
    }

    /// 视图里这一点戳到的是哪儿；不在形象上返回 nil
    func pokeZone(at point: NSPoint) -> PetPokeZone? {
        guard let image = currentImage, isOpaquePetPixel(at: point) else { return nil }
        return PetPokeZone.zone(
            at: point,
            imageRect: aspectFitRect(for: image.size, in: petCanvasRect),
            facingRight: isFacingRight
        )
    }

    func handlePoke(at point: NSPoint, random: Double = Double.random(in: 0..<1)) {
        guard canReactToPoke, let zone = pokeZone(at: point), let clip = behavior.poked(zone) else { return }
        if clip == .startled {
            animationEngine.hop(pixels: Self.startledHopPixels, duration: Self.startledHopDuration)
        }
        // 上一下戳出来的话可以换掉；正显示着别的话（离开时的汇总、出错提示）就不盖掉它
        let bubbleIsFree = transientBubbleContainer.isHidden || PetPokeCopy.isPokeLine(transientBubbleLabel.stringValue)
        if bubbleIsFree, let line = PetPokeCopy.line(for: clip, random: random) {
            showTransientMessage(line, duration: Self.pokeBubbleDuration)
        }
        let pokedFromRight = point.x >= (petBodyRect?.midX ?? petCanvasRect.midX)
        onPokeReaction?(clip, pokedFromRight)
    }
}
