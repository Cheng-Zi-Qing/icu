import AppKit
import Foundation

final class HealthReportWindowController: NSWindowController, NSWindowDelegate {
    enum Mode: Int {
        case today = 0
        case week = 1
    }

    private enum Layout {
        static let windowSize = NSSize(width: 336, height: 288)
        static let contentInset: CGFloat = 12
        static let stackSpacing: CGFloat = 8
        static let metricSpacing: CGFloat = 4
    }

    private let todaySummary: HealthDaySummary
    private let weekSummary: HealthWeekSummary

    private let panelView = NSView()
    private let titleLabel = NSTextField(labelWithString: "今日累计")
    private let summaryLabel = NSTextField(labelWithString: "")
    private let modeControl = NSSegmentedControl(labels: ["今日", "本周"], trackingMode: .selectOne, target: nil, action: nil)
    private let modeLabel = NSTextField(labelWithString: "")
    private let metricsStack = NSStackView()
    private let dateFormatter: DateFormatter
    private var currentMode: Mode = .today
    private var themeObserver: NSObjectProtocol?

    init(todaySummary: HealthDaySummary, weekSummary: HealthWeekSummary) {
        self.todaySummary = todaySummary
        self.weekSummary = weekSummary
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        self.dateFormatter = formatter

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.windowSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "今日累计"

        super.init(window: window)
        window.delegate = self

        buildUI()
        applyTheme()
        renderCurrentMode()
        subscribeToThemeChanges()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    @objc func handleModeChange(_ sender: NSSegmentedControl?) {
        let selectedSegment = sender?.selectedSegment ?? Mode.today.rawValue
        currentMode = Mode(rawValue: selectedSegment) ?? .today
        renderCurrentMode()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else {
            return
        }

        panelView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(panelView)

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = Layout.stackSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        panelView.addSubview(stackView)

        titleLabel.identifier = NSUserInterfaceItemIdentifier("healthReport.titleLabel")
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        summaryLabel.identifier = NSUserInterfaceItemIdentifier("healthReport.summaryLabel")
        summaryLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        modeControl.identifier = NSUserInterfaceItemIdentifier("healthReport.modeControl")
        modeControl.selectedSegment = Mode.today.rawValue
        modeControl.target = self
        modeControl.action = #selector(handleModeChange(_:))
        modeControl.segmentStyle = .rounded
        modeControl.controlSize = .small
        modeControl.setWidth(70, forSegment: 0)
        modeControl.setWidth(70, forSegment: 1)

        modeLabel.identifier = NSUserInterfaceItemIdentifier("healthReport.modeLabel")
        modeLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        metricsStack.orientation = .vertical
        metricsStack.alignment = .leading
        metricsStack.spacing = Layout.metricSpacing
        metricsStack.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(summaryLabel)
        stackView.addArrangedSubview(modeControl)
        stackView.addArrangedSubview(modeLabel)
        stackView.addArrangedSubview(metricsStack)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Layout.contentInset),
            panelView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Layout.contentInset),
            panelView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Layout.contentInset),
            panelView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Layout.contentInset),

            stackView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: Layout.contentInset),
            stackView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -Layout.contentInset),
            stackView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: Layout.contentInset),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: panelView.bottomAnchor, constant: -Layout.contentInset),
        ])
    }

    private func subscribeToThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: .icuThemeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyTheme()
            self?.renderCurrentMode()
        }
    }

    private func applyTheme() {
        let theme = ThemeManager.shared.currentTheme
        if let window {
            ThemedComponents.styleWindow(window, theme: theme)
        }

        ThemedComponents.stylePanel(panelView, theme: theme)
        ThemedComponents.styleLabel(titleLabel, theme: theme, tone: .accent, font: ThemedComponents.titleFont(theme))
        ThemedComponents.styleLabel(summaryLabel, theme: theme, tone: .secondary, font: ThemedComponents.smallFont(theme))
        ThemedComponents.styleLabel(modeLabel, theme: theme, tone: .accent, font: ThemedComponents.bodyFont(theme))
        modeControl.font = ThemedComponents.smallFont(theme)

        for label in metricsStack.arrangedSubviews.compactMap({ $0 as? NSTextField }) {
            ThemedComponents.styleLabel(label, theme: theme, tone: .primary, font: ThemedComponents.smallFont(theme))
        }
    }

    private func renderCurrentMode() {
        modeControl.selectedSegment = currentMode.rawValue
        modeLabel.stringValue = currentMode == .today ? "今日" : "本周"
        summaryLabel.stringValue = currentMode == .today ? todaySummaryText() : weekSummaryText()

        let theme = ThemeManager.shared.currentTheme
        for view in metricsStack.arrangedSubviews {
            metricsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let metricLines = currentMode == .today ? todayMetricLines() : weekMetricLines()
        for line in metricLines {
            let label = NSTextField(wrappingLabelWithString: line)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            ThemedComponents.styleLabel(label, theme: theme, tone: .primary, font: ThemedComponents.smallFont(theme))
            metricsStack.addArrangedSubview(label)
        }
    }

    private func todaySummaryText() -> String {
        "护眼 \(formatPercent(todaySummary.eyeReminderCompletionRate)) / 喝水 \(formatPercent(todaySummary.hydrationReminderCompletionRate))，工作 \(formatDuration(todaySummary.workDuration))"
    }

    private func weekSummaryText() -> String {
        "活跃 \(weekSummary.activeDayCount) 天，护眼 \(formatPercent(weekSummary.eyeReminderCompletionRate)) / 喝水 \(formatPercent(weekSummary.hydrationReminderCompletionRate))"
    }

    private func todayMetricLines() -> [String] {
        [
            "工作时长 \(formatDuration(todaySummary.workDuration))",
            "专注次数 \(todaySummary.focusCount)",
            "专注时长 \(formatDuration(todaySummary.focusDuration))",
            "休息次数 \(todaySummary.breakCount)",
            reminderLine(title: "护眼提醒", counts: todaySummary.eyeReminder),
            "护眼完成率 \(formatPercent(todaySummary.eyeReminderCompletionRate))",
            reminderLine(title: "喝水提醒", counts: todaySummary.hydrationReminder),
            "喝水完成率 \(formatPercent(todaySummary.hydrationReminderCompletionRate))",
        ]
    }

    private func weekMetricLines() -> [String] {
        [
            "本周工作时长 \(formatDuration(weekSummary.workDuration))",
            "本周专注次数 \(weekSummary.focusCount)",
            "本周专注时长 \(formatDuration(weekSummary.focusDuration))",
            "本周休息次数 \(weekSummary.breakCount)",
            "护眼完成率 \(formatPercent(weekSummary.eyeReminderCompletionRate))",
            "本周喝水完成率 \(formatPercent(weekSummary.hydrationReminderCompletionRate))",
            trendLine(),
        ]
    }

    private func trendLine() -> String {
        let activeDays = weekSummary.days.filter(\.hasActivity)
        guard !activeDays.isEmpty else {
            return "趋势 暂无活跃记录"
        }

        let fragments = activeDays.prefix(4).map { day in
            "\(dateFormatter.string(from: day.date)) \(compactDaySummary(day))"
        }

        if activeDays.count > fragments.count {
            return "趋势 " + fragments.joined(separator: " · ") + " · ..."
        }

        return "趋势 " + fragments.joined(separator: " · ")
    }

    private func compactDaySummary(_ summary: HealthDaySummary) -> String {
        if summary.workDuration > 0 {
            return formatDuration(summary.workDuration)
        }
        if summary.focusDuration > 0 {
            return "专注 \(formatDuration(summary.focusDuration))"
        }
        let reminderCount = summary.eyeReminder.shown + summary.hydrationReminder.shown
        if reminderCount > 0 {
            return "提醒 \(reminderCount)"
        }
        return "有活动"
    }

    private func reminderLine(title: String, counts: HealthReminderCounts) -> String {
        "\(title) 已展示 \(counts.shown) / 已完成 \(counts.completed) / 稍后 \(counts.snoozed) / 跳过 \(counts.skipped)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func formatPercent(_ rate: Double) -> String {
        "\(Int((rate * 100).rounded()))%"
    }
}
