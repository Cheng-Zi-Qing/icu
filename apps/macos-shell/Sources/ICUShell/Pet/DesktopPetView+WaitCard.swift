import AppKit

/// 在等你时头顶的卡片：和提醒卡占同一个位置（窗口按提醒卡的高度展开）
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
        let y = usesExpandedReminderLayout ? petStageTop + LayoutMetrics.reminderGap : max(26, bounds.height - height - 8)
        waitCardView.frame = NSRect(x: (bounds.width - width) / 2, y: y, width: width, height: height)
    }
}
