import AppKit

/// 自己接管桌宠拖拽：移动窗口 + 驱动 DragPhysics
///
/// 不使用 `NSWindow.performDrag`：那会把整个拖拽交给系统，视图拿不到拖动/松手事件，
/// 也就无法根据速度做摆动、拉长等效果。
final class PetDragController {
    private(set) var physics: DragPhysics
    private var pressMouseLocation: CGPoint = .zero
    private var pressWindowOrigin: CGPoint = .zero
    private let timeProvider: () -> TimeInterval

    init(
        config: DragPhysicsConfig = DragPhysicsConfig(),
        timeProvider: @escaping () -> TimeInterval = { CACurrentMediaTime() }
    ) {
        self.physics = DragPhysics(config: config)
        self.timeProvider = timeProvider
    }

    var isDragging: Bool { physics.isDragging }

    func mouseDown(mouseLocation: CGPoint, windowOrigin: CGPoint) {
        pressMouseLocation = mouseLocation
        pressWindowOrigin = windowOrigin
        physics = physics.pressed(at: mouseLocation, at: timeProvider())
    }

    /// 返回新的窗口原点；还没越过拖拽阈值时返回 nil。
    /// `keepVisible` 是窗口内必须留在屏幕上的部分（身体 + 正在显示的气泡），
    /// 窗口其余透明部分可以出屏，这样身体才能真正贴到屏幕边。
    func mouseDragged(mouseLocation: CGPoint, keepVisible: CGRect, visibleFrame: CGRect?) -> CGPoint? {
        let time = timeProvider()
        physics = physics.moved(to: mouseLocation, at: time).stepped(to: time)
        guard physics.isDragging else {
            return nil
        }

        // 拎着时身体画高了 liftHeight；窗口（落地的地面）放低同样多，被拎的豚鼠正好在手里，
        // 松手后才从手里往下掉这一截
        let proposed = CGPoint(
            x: pressWindowOrigin.x + (mouseLocation.x - pressMouseLocation.x),
            y: pressWindowOrigin.y + (mouseLocation.y - pressMouseLocation.y) - physics.config.liftHeight
        )
        guard let visibleFrame else {
            return proposed
        }
        return EdgeDockLayout.clampedOrigin(proposed, keepVisible: keepVisible, visibleFrame: visibleFrame)
    }

    /// 返回这次松手是否结束了一次拖拽（false 表示是点击）
    func mouseUp() -> Bool {
        physics = physics.released(at: timeProvider())
        return physics.lastReleaseWasDrag == true
    }

    /// 每帧调用：推进物理并返回渲染输出
    func output(at time: TimeInterval) -> DragOutput {
        physics = physics.stepped(to: time)
        return physics.output(at: time)
    }

    /// 鼠标所在屏幕的可见区域
    static func visibleFrame(containing point: CGPoint) -> CGRect? {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        return screen?.visibleFrame
    }
}
