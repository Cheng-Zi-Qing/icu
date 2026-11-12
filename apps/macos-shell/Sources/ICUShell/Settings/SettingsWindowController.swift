import AppKit

/// 设置窗口：改了就立刻保存并生效，没有「保存」按钮
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settingsView: SettingsView
    private let onChange: (SettingsForm) throws -> Void
    private let onSelectLanguage: (AppLanguage) -> Void
    private(set) var form: SettingsForm

    /// - Parameter onChange: 保存并应用新设置；抛错时窗口底部显示一句提示，表单保持新值方便再试
    /// - Parameter onSelectLanguage: 换了界面语言：写配置 + 重读文案
    init(
        form: SettingsForm,
        language: AppLanguage = .chinese,
        decoration: NSImage?,
        onSelectLanguage: @escaping (AppLanguage) -> Void = { _ in },
        onChange: @escaping (SettingsForm) throws -> Void
    ) {
        self.form = form
        self.onChange = onChange
        self.onSelectLanguage = onSelectLanguage
        var step: ((SettingsForm.Field, Int) -> Void)?
        var select: ((EyeCareMode) -> Void)?
        var selectLanguage: ((AppLanguage) -> Void)?
        settingsView = SettingsView(
            form: form,
            language: language,
            decoration: decoration,
            onStep: { field, direction in step?(field, direction) },
            onSelectMode: { mode in select?(mode) },
            onSelectLanguage: { language in selectLanguage?(language) }
        )

        let window = PixelWindow(size: SettingsView.preferredSize(), title: TextCatalog.shared.text("settings.title"), content: settingsView)
        super.init(window: window)
        window.delegate = self

        step = { [weak self] field, direction in self?.step(field, by: direction) }
        select = { [weak self] mode in self?.select(eyeMode: mode) }
        selectLanguage = { [weak self] language in self?.select(language: language) }
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

    func select(language: AppLanguage) {
        guard language != settingsView.language else { return }
        settingsView.language = language
        onSelectLanguage(language)
    }

    /// 文案换了（语言切换）：标题栏、行标签、模式名、说明都重画
    func reloadCopy() {
        window?.title = TextCatalog.shared.text("settings.title")
        settingsView.reloadCopy()
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
            settingsView.message = TextCatalog.shared.text("common.save_failed")
        }
    }

    @objc private func closeSettings() {
        window?.performClose(nil)
    }
}
