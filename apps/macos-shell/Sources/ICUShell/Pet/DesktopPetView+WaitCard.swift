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
        let width = min(bounds.width - 4, 200)
        let height = AgentWaitCardView.height
        let y = usesExpandedCardLayout ? petStageTop + LayoutMetrics.cardGap : max(26, bounds.height - height - 8)
        waitCardView.frame = NSRect(x: (bounds.width - width) / 2, y: y, width: width, height: height)
    }
}
