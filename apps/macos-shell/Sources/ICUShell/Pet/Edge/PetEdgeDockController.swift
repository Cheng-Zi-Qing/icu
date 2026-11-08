import AppKit

/// 贴边吸附 + 自动藏边 + 鼠标靠近探出来
///
/// 流程：
/// 1. 松手时身体离左 / 右 / 下边不超过 `snapDistance` → 滑过去贴住
/// 2. 贴在左右边、`autoHideDelay` 内没碰它 → 先整只躲到屏幕边外，
///    再换成「探头扒边」的专用形象把脑袋探出来（没有探头图的宠物退回只露 `peekWidth`）
/// 3. 鼠标移到露出的部分，或者有提醒卡片 → 吓一跳缩回去、换回正常形象再滑出来
/// 贴左边时形象镜像，让脸朝屏幕里。
final class PetEdgeDockController {
    private enum Timing {
        static let snap: TimeInterval = 0.22
        static let hide: TimeInterval = 0.35
        static let reveal: TimeInterval = 0.2
        static let duck: TimeInterval = 0.22
        static let peekOut: TimeInterval = 0.28
        static let peekIn: TimeInterval = 0.14
        /// 吓一跳后缩回去：比平时慢一点，让 > < 那一帧看得见
        static let flinchIn: TimeInterval = 0.3
    }

    private weak var window: NSWindow?
    private let settings: EdgeSnapSettings
    /// 身体在窗口内的矩形（随朝向变化）
    private let bodyRectProvider: () -> CGRect?
    /// 给定身体的屏幕矩形，返回它所在屏幕的可见区域
    private let visibleFrameProvider: (CGRect) -> CGRect?
    private let mover: WindowMoving
    private let hideScheduler: HideScheduling

    /// true 表示镜像（脸朝右）
    var onFacingChanged: ((Bool) -> Void)?
    /// 吸附完成后的窗口原点，用于保存位置（藏边的位置不保存）
    var onDockedOriginSettled: ((CGPoint) -> Void)?
    /// 当前宠物有没有探头扒边的专用形象
    var canPeek: () -> Bool = { false }
    /// 切换探头形象；切换后 `bodyRectProvider` 应返回探头形象的身体矩形
    var onPeekChanged: ((Bool) -> Void)?
    /// 探着头被碰到：换成吓一跳的那一帧（随后缩回边后）
    var onPeekFlinch: (() -> Void)?

    private(set) var dock: EdgeDock = .none
    private(set) var isHidden = false
    private(set) var isPeeking = false
    private var isMoving = false
    private var dockedOrigin: CGPoint?
    private var isPointerInside = false
    private var isOverlayVisible = false
    private var isDragging = false

    init(
        window: NSWindow,
        settings: EdgeSnapSettings,
        bodyRectProvider: @escaping () -> CGRect?,
        visibleFrameProvider: @escaping (CGRect) -> CGRect? = PetEdgeDockController.visibleFrame(containing:),
        mover: WindowMoving = WindowSlideAnimator(),
        hideScheduler: HideScheduling = MainQueueHideScheduler()
    ) {
        self.window = window
        self.settings = settings
        self.bodyRectProvider = bodyRectProvider
        self.visibleFrameProvider = visibleFrameProvider
        self.mover = mover
        self.hideScheduler = hideScheduler
    }

    /// 窗口正在被贴边逻辑移动或处于藏边状态：这时的位置不该当作用户摆放的位置保存
    var isManagingWindowPosition: Bool { isMoving || isHidden }

    // MARK: - 事件

    func dragStarted() {
        isDragging = true
        hideScheduler.cancel()
        mover.cancel()
        isMoving = false
        isHidden = false
        setPeeking(false)
        dock = .none
        dockedOrigin = nil
    }

    func dragEnded() {
        isDragging = false
        settle(animated: true)
    }

    /// 启动时：上次停在边上就恢复贴边（含朝向和自动藏边）
    func restoreAfterLaunch() {
        settle(animated: false)
    }

    func pointerEntered() {
        isPointerInside = true
        hideScheduler.cancel()
        reveal()
    }

    func pointerExited() {
        isPointerInside = false
        scheduleHideIfNeeded()
    }

    /// 气泡 / 提醒卡片出现时必须完整露出来
    func overlayVisibilityChanged(_ visible: Bool) {
        isOverlayVisible = visible
        if visible {
            hideScheduler.cancel()
            reveal()
        } else {
            scheduleHideIfNeeded()
        }
    }

    // MARK: - Private

    private func settle(animated: Bool) {
        guard
            settings.isEnabled,
            let window,
            let body = bodyRectProvider(),
            let visibleFrame = visibleFrame(for: window.frame.origin, body: body)
        else {
            return
        }

        let newDock = EdgeDockLayout.dock(
            for: window.frame.origin, bodyRect: body, visibleFrame: visibleFrame, snapDistance: settings.snapDistance
        )
        guard newDock.isDocked else {
            dock = .none
            dockedOrigin = nil
            return
        }

        if let edge = newDock.horizontal {
            setFacingRight(edge == .left)
        }
        // 镜像后身体在窗口里的位置变了，要用新的矩形算贴边位置
        let facedBody = bodyRectProvider() ?? body
        let target = EdgeDockLayout.dockedOrigin(
            window.frame.origin, dock: newDock, bodyRect: facedBody, visibleFrame: visibleFrame
        )
        dock = newDock
        dockedOrigin = target
        slide(window, to: target, duration: animated ? Timing.snap : 0) { [weak self] in
            self?.onDockedOriginSettled?(target)
            self?.scheduleHideIfNeeded()
        }
    }

    private var canHide: Bool {
        settings.isEnabled
            && settings.autoHideDelay > 0
            && dock.horizontal != nil
            && !isHidden
            && !isPointerInside
            && !isOverlayVisible
            && !isDragging
    }

    private func scheduleHideIfNeeded() {
        guard canHide else { return }
        hideScheduler.schedule(after: settings.autoHideDelay) { [weak self] in
            self?.hide()
        }
    }

    private func hide() {
        guard
            canHide,
            let window,
            let edge = dock.horizontal,
            let dockedOrigin,
            let body = bodyRectProvider(),
            let visibleFrame = visibleFrame(for: dockedOrigin, body: body)
        else {
            return
        }

        isHidden = true
        guard canPeek() else {
            let target = EdgeDockLayout.hiddenOrigin(
                dockedOrigin: dockedOrigin, edge: edge, bodyRect: body, visibleFrame: visibleFrame, peekWidth: settings.peekWidth
            )
            slide(window, to: target, duration: Timing.hide) {}
            return
        }

        // 先整只躲到屏幕外，再换探头形象把脑袋探出来
        let behind = EdgeDockLayout.behindOrigin(dockedOrigin: dockedOrigin, edge: edge, bodyRect: body, visibleFrame: visibleFrame)
        slide(window, to: behind, duration: Timing.duck) { [weak self] in
            self?.peekOut(window: window, edge: edge, dockedOrigin: dockedOrigin, visibleFrame: visibleFrame)
        }
    }

    private func peekOut(window: NSWindow, edge: HorizontalDockEdge, dockedOrigin: CGPoint, visibleFrame: CGRect) {
        setPeeking(true)
        guard let peekBody = bodyRectProvider() else { return }
        window.setFrameOrigin(EdgeDockLayout.behindOrigin(
            dockedOrigin: dockedOrigin, edge: edge, bodyRect: peekBody, visibleFrame: visibleFrame
        ))
        let target = EdgeDockLayout.hiddenOrigin(
            dockedOrigin: dockedOrigin, edge: edge, bodyRect: peekBody, visibleFrame: visibleFrame, peekWidth: peekBody.width
        )
        slide(window, to: target, duration: Timing.peekOut) {}
    }

    private func reveal() {
        guard isHidden, let window, let dockedOrigin else { return }
        isHidden = false
        guard
            isPeeking,
            let edge = dock.horizontal,
            let peekBody = bodyRectProvider(),
            let visibleFrame = visibleFrame(for: dockedOrigin, body: peekBody)
        else {
            setPeeking(false)
            slide(window, to: dockedOrigin, duration: Timing.reveal) {}
            return
        }

        // 吓一跳，缩回屏幕外，换回正常形象，再滑出来
        onPeekFlinch?()
        let peekBehind = EdgeDockLayout.behindOrigin(dockedOrigin: dockedOrigin, edge: edge, bodyRect: peekBody, visibleFrame: visibleFrame)
        slide(window, to: peekBehind, duration: Timing.flinchIn) { [weak self] in
            guard let self else { return }
            self.setPeeking(false)
            if let body = self.bodyRectProvider() {
                window.setFrameOrigin(EdgeDockLayout.behindOrigin(
                    dockedOrigin: dockedOrigin, edge: edge, bodyRect: body, visibleFrame: visibleFrame
                ))
            }
            self.slide(window, to: dockedOrigin, duration: Timing.reveal) {}
        }
    }

    private func setPeeking(_ peeking: Bool) {
        guard peeking != isPeeking else { return }
        isPeeking = peeking
        onPeekChanged?(peeking)
    }

    private func slide(_ window: NSWindow, to origin: CGPoint, duration: TimeInterval, completion: @escaping () -> Void) {
        isMoving = true
        mover.move(window, to: origin, duration: duration) { [weak self] in
            self?.isMoving = false
            completion()
        }
    }

    /// 每次贴边都报一次：转头看鼠标会自己改朝向，这里不能凭「上次报过」就跳过
    private func setFacingRight(_ facingRight: Bool) {
        onFacingChanged?(facingRight)
    }

    private func visibleFrame(for origin: CGPoint, body: CGRect) -> CGRect? {
        visibleFrameProvider(body.offsetBy(dx: origin.x, dy: origin.y))
    }

    /// 身体中心所在屏幕的可见区域（多显示器时按身体位置选屏）
    static func visibleFrame(containing bodyFrame: CGRect) -> CGRect? {
        let center = CGPoint(x: bodyFrame.midX, y: bodyFrame.midY)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main
        return screen?.visibleFrame
    }
}
