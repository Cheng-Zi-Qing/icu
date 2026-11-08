import AppKit

/// Agent 在干活时演的小场景（翻书、写字、吃饭……）。
/// 画面优先级：拖拽 > 贴边探头 > 干活小场景 > 摸头打盹片段 > 待机动画。
extension DesktopPetView {
    var workActivity: AgentActivity? { workPlayer.activity }

    /// nil = 不演了（在等你、干完了、没活），回到平时的画面
    func setWorkActivity(_ activity: AgentActivity?) {
        workPlayer.play(activity)
    }

    func makeWorkPlayer() -> PetWorkScenePlayer {
        let player = PetWorkScenePlayer()
        player.onImageChanged = { [weak self] image in
            self?.applyWorkImage(image)
        }
        return player
    }

    private func applyWorkImage(_ image: NSImage?) {
        workImage = image
        guard !isShowingDragPose && !isPeeking else { return }
        present(restingImage)
    }
}
