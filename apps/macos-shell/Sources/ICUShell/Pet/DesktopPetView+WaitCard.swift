import AppKit

/// 在等你时头顶的卡片（窗口按卡片的高度展开）。健康提醒不在这里，在屏幕中央
extension DesktopPetView {
    var isShowingWaitCard: Bool { !waitCardView.isHidden }

    func setupWaitCard() {
        waitCardView = AgentWaitCardView(frame: .zero)
        waitCardView.identifier = NSUserInterfaceItemIdentifier("desktopPet.waitCard")
        waitCardView.isHidden = true
        addOverlaySubview(waitCardView)
    }

    func showWaitCard(_ content: AgentWaitCardContent, onJump: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        waitCardView.configure(with: content)
        waitCardView.onJump = onJump
        waitCardView.onDismiss = onDismiss
        let wasHidden = waitCardView.isHidden
        layoutWaitCard()
        waitCardView.isHidden = false
        if wasHidden {
            notifyOverlayLayoutModeChanged()
        }
    }

    func hideWaitCard() {
        guard !waitCardView.isHidden else { return }
        waitCardView.isHidden = true
        notifyOverlayLayoutModeChanged()
    }

    func layoutWaitCard() {
        guard waitCardView != nil else { return }
        // 贴边时窗口一边在屏幕外：卡片只用看得见的那块宽度，对准身体
        let area = onScreenBounds
        let width = min(area.width - 4, 200)
        let height = AgentWaitCardView.height
        let y = usesExpandedCardLayout ? petStageTop + LayoutMetrics.cardGap : max(26, bounds.height - height - 8)
        let center = (petBodyRect ?? petCanvasRect).midX
        let x = min(max(center - width / 2, area.minX + 2), area.maxX - 2 - width)
        waitCardView.frame = NSRect(x: x.rounded(), y: y, width: width, height: height)
    }
}
