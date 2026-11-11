import AppKit

/// 把提醒卡摆到屏幕中央：不抢键盘焦点（你正打着的字不会断），浮在所有窗口上面，从上面落下来停住。
/// 挂着没人理够久就自己收起，当作跳过
@MainActor
final class ReminderStagePresenter {
    private enum Motion {
        static let dropDistance: CGFloat = 28
        static let dropDuration: TimeInterval = 0.22
    }

    private(set) var panel: NSPanel?
    private(set) var stageView: ReminderStageView?
    private var timeout: DispatchWorkItem?
    private let visibleFrame: () -> CGRect
    private let unansweredTimeout: TimeInterval

    var isShowing: Bool { panel != nil }

    /// `visibleFrame`：卡片摆在哪块屏幕上（默认鼠标所在的那块）
    init(
        visibleFrame: @escaping () -> CGRect = ReminderStagePresenter.pointerScreenVisibleFrame,
        unansweredTimeout: TimeInterval = ReminderStageRules.unansweredTimeout
    ) {
        self.visibleFrame = visibleFrame
        self.unansweredTimeout = unansweredTimeout
    }

    /// 亮出提醒卡。点了哪个按钮、或者没人理到超时（算跳过），都只报一次 `onAction`
    func show(
        content: ReminderCardContent,
        petImage: @escaping (TimeInterval) -> NSImage?,
        onAction: @escaping (HealthReminderOutcome) -> Void
    ) {
        dismiss()
        let view = ReminderStageView(content: content, petImage: petImage)
        let target = ReminderStageRules.frame(size: ReminderStageView.preferredSize, in: visibleFrame())
        let panel = NSPanel(
            contentRect: target.offsetBy(dx: 0, dy: Motion.dropDistance),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // 像素板子自己有硬投影；系统的柔和阴影再垫一层，在花哨的桌面上也跳得出来
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = view
        view.onAction = { [weak self] outcome in
            self?.dismiss()
            onAction(outcome)
        }
        self.panel = panel
        stageView = view
        panel.orderFrontRegardless()
        view.startAnimating()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.dropDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
        }
        scheduleTimeout(onAction)
    }

    /// 收起，不报结果（被「在等你」盖过、或者已经点了按钮）
    func dismiss() {
        timeout?.cancel()
        timeout = nil
        stageView?.stopAnimating()
        stageView?.onAction = nil
        stageView = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func scheduleTimeout(_ onAction: @escaping (HealthReminderOutcome) -> Void) {
        guard unansweredTimeout > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isShowing else { return }
                self.dismiss()
                onAction(.skipped)
            }
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + unansweredTimeout, execute: work)
    }

    nonisolated static func pointerScreenVisibleFrame() -> CGRect {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main ?? NSScreen.screens.first
        return screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
