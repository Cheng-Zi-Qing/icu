import AppKit

/// 转头看鼠标：原地蹦一格，同时换到另一边。瞬间镜像太突兀，蹦一下就像它自己转过身来。
/// 以前中间先闪一张正面坐姿，用户嫌正面干坐着光秃秃的不可爱（2026-11-11），改成蹦。
/// 贴边、追球、放下时的转向不蹦（见 setFacingRight）
extension DesktopPetView {
    static let turnHopPixels = 1
    static let turnHopDuration: CFTimeInterval = 0.24

    func turn(toFacingRight facingRight: Bool) {
        guard facingRight != isFacingRight else { return }
        if !isShowingDragPose && !isPeeking {
            animationEngine.hop(pixels: Self.turnHopPixels, duration: Self.turnHopDuration)
        }
        setFacingRight(facingRight)
    }
}
