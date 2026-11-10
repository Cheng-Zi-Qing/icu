import AppKit

final class ContextMenuPanelController {
    private let floatingPanelController = FloatingPanelController()
    private let onAction: (DesktopPetMenuAction) -> Void

    private(set) var currentPanel: ThemedMenuPanel?

    /// 「今日报告…」的数据；nil（或今天一条记录都没有）= 没东西可看，只让桌宠说一句
    var todayReportProvider: (() -> HealthDaySummary?)?
    var cupsGoalProvider: () -> Int = { HydrationPlan(profile: HealthProfile.default).cups }
    var onEmptyReport: (() -> Void)?

    var isPresented: Bool {
        floatingPanelController.isPresented
    }

    init(onAction: @escaping (DesktopPetMenuAction) -> Void) {
        self.onAction = onAction
        floatingPanelController.onDidDismiss = { [weak self] in
            self?.currentPanel = nil
        }
    }

    func present(
        from model: DesktopPetMenuModel,
        summary: MenuTodaySummary? = nil,
        event: NSEvent,
        in contentView: NSView
    ) {
        let sections = makeSections(from: model)
        let size = ThemedMenuPanel.preferredSize(for: sections, hasSummary: summary != nil)

        // 菜单锚到右键点：左边贴着点击点往左 12pt，底边比点击点高 12pt
        guard let window = contentView.window ?? NSApp.window(withWindowNumber: event.windowNumber) else {
            return
        }
        let clickPoint = window.convertPoint(toScreen: event.locationInWindow)
        let frame = NSRect(
            x: clickPoint.x - 12,
            y: clickPoint.y - size.height + 12,
            width: size.width,
            height: size.height
        )

        let panel = ThemedMenuPanel(sections: sections, summary: summary) { [weak self] id in
            guard
                let self,
                let action = DesktopPetMenuAction(rawValue: id)
            else {
                return
            }

            // 「今日报告…」要留着桌宠窗口才能把面板锚到它顶上，所以这里不关菜单，
            // 由报告面板把菜单顶掉（FloatingPanelController.present 会先关掉上一个）
            if action == .showTodayReport {
                self.showTodayReport(above: contentView.window)
                return
            }

            self.dismiss()
            self.onAction(action)
        }

        floatingPanelController.present(contentView: panel, frame: frame)
        currentPanel = panel
    }

    /// 「今日报告…」：像素风浮层，锚在桌宠窗口顶上（水平居中、底边高出桌宠顶边 12pt），
    /// 不挡桌宠、不压光标，也不贴屏幕边
    func showTodayReport(above window: NSWindow?) {
        guard let window else {
            return
        }

        guard let report = todayReportProvider?(), report.hasActivity else {
            // 没东西可看：先关菜单再让桌宠说一句
            dismiss()
            onEmptyReport?()
            return
        }

        let reportView = MenuTodayReportView(report: report, cupsGoal: cupsGoalProvider())
        let size = reportView.frame.size
        let frame = NSRect(
            x: window.frame.midX - size.width / 2,
            y: window.frame.maxY + 12,
            width: size.width,
            height: size.height
        )

        floatingPanelController.present(contentView: reportView, frame: frame)
    }

    func dismiss() {
        floatingPanelController.dismiss()
    }

    private func makeSections(from model: DesktopPetMenuModel) -> [ThemedMenuPanelSection] {
        model.sections.map { section in
            ThemedMenuPanelSection(
                items: section.map { action in
                    ThemedMenuPanelItem(
                        id: action.rawValue,
                        title: action.title,
                        tone: Self.tone(for: action)
                    )
                }
            )
        }
    }

    private static func tone(for action: DesktopPetMenuAction) -> ThemedMenuPanelItem.Tone {
        switch action {
        case .startWork, .resumeWorking: return .primary
        case .quitApp: return .destructive
        default: return .standard
        }
    }
}
