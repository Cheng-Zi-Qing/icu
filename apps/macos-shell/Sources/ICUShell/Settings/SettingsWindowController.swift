import AppKit

/// 设置窗口：改了就立刻保存并生效，没有「保存」按钮
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsView: SettingsView
    private let onChange: (SettingsForm) throws -> Void
    private(set) var form: SettingsForm

    /// - Parameter onChange: 保存并应用新设置；抛错时窗口底部显示一句提示，表单保持新值方便再试
    init(form: SettingsForm, decoration: NSImage?, onChange: @escaping (SettingsForm) throws -> Void) {
        self.form = form
        self.onChange = onChange
        var step: ((SettingsForm.Field, Int) -> Void)?
        var select: ((EyeCareMode) -> Void)?
        settingsView = SettingsView(
            form: form,
            decoration: decoration,
            onStep: { field, direction in step?(field, direction) },
            onSelectMode: { mode in select?(mode) }
        )

        let window = PixelWindow(size: SettingsView.preferredSize(), title: "ICU 设置", content: settingsView)
        super.init(window: window)
        window.delegate = self

        step = { [weak self] field, direction in self?.step(field, by: direction) }
        select = { [weak self] mode in self?.select(eyeMode: mode) }
        settingsView.closeButton.target = self
        settingsView.closeButton.action = #selector(closeSettings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        (window as? PixelWindow)?.present()
    }

    var view: SettingsView { settingsView }

    func step(_ field: SettingsForm.Field, by direction: Int) {
        apply(form.stepped(field, by: direction))
    }

    func select(eyeMode: EyeCareMode) {
        apply(form.with(eyeMode: eyeMode))
    }

    private func apply(_ next: SettingsForm) {
        guard next != form else { return }
        form = next
        settingsView.form = next
        do {
            try onChange(next)
            settingsView.message = nil
        } catch {
            NSLog("[Settings] failed to save settings: \(error.localizedDescription)")
            settingsView.message = "没存上，再点一次试试"
        }
    }

    @objc private func closeSettings() {
        window?.performClose(nil)
    }
}
