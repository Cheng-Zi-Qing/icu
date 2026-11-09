import AppKit

/// 场景：Agent 在干活时的小场景（翻书、写字、吃饭……），以及在等你 / 干完了 / 出错了的三段动作。
/// 画面优先级：拖拽 > 贴边探头 > 场景 > 摸头打盹片段 > 待机动画。
extension DesktopPetView {
    var scene: PetScene? { workPlayer.scene }
    var workActivity: AgentActivity? { workPlayer.activity }

    /// nil = 不演了，回到平时的画面
    func setScene(_ scene: PetScene?) {
        workPlayer.play(scene)
    }

    func setWorkActivity(_ activity: AgentActivity?) {
        setScene(activity.map(PetScene.work))
    }

    func makeWorkPlayer() -> PetWorkScenePlayer {
        let player = PetWorkScenePlayer()
        player.onImageChanged = { [weak self] image in
            self?.applyWorkImage(image)
        }
        player.onHop = { [weak self] hop in
            // 被拎着、探着头时不跳
            guard let self, !self.isDraggingPet, !self.isPeeking else { return }
            self.animationEngine.hop(pixels: hop.pixels, duration: hop.duration)
        }
        player.onFinished = { [weak self] scene in
            self?.onSceneFinished?(scene)
        }
        return player
    }

    private func applyWorkImage(_ image: NSImage?) {
        workImage = image
        guard !isShowingDragPose && !isPeeking else { return }
        present(restingImage)
    }
}
