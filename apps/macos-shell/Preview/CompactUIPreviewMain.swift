import AppKit
import Foundation

@main
struct CompactUIPreviewMain {
    static func main() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)

        let controller = try CompactUIPreviewController()
        application.delegate = controller
        withExtendedLifetime(controller) {
            application.run()
        }
    }
}

private final class CompactUIPreviewController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let environment: CompactUIPreviewEnvironment
    private let launcherWindow: NSWindow
    private let generationCoordinator: GenerationCoordinator
    private var avatarController: AvatarSelectorWindowController?

    init(fileManager: FileManager = .default) throws {
        environment = try CompactUIPreviewEnvironment(fileManager: fileManager)
        generationCoordinator = environment.makeGenerationCoordinator()
        launcherWindow = CompactUIPreviewController.makeLauncherWindow()

        super.init()

        launcherWindow.delegate = self
        buildLauncherUI()
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.cleanup()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showLauncher()
        FileHandle.standardOutput.write(Data("[compact_ui_preview] Launcher ready\n".utf8))
    }

    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }

    func showLauncher() {
        launcherWindow.center()
        launcherWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAvatarPreview() {
        if let avatarController {
            avatarController.present()
            return
        }

        let environment = self.environment
        let controller = AvatarSelectorWindowController(
            avatars: environment.previewAvatars,
            currentAvatarID: environment.previewAvatars.first?.id,
            themePromptOptimizer: { prompt in
                "Preview optimized theme prompt: \(prompt)"
            },
            themeDraftGenerator: { _ in
                environment.makePreviewThemePack()
            },
            themeDraftApplier: { pack in
                try environment.themeManager.apply(pack)
            },
            avatarPromptOptimizer: { prompt in
                "Preview optimized avatar prompt: \(prompt)"
            },
            avatarPreviewGenerator: { _ in
                try environment.makePreviewAvatarDraft()
            },
            avatarSaveHandler: { request in
                request.name.isEmpty ? "preview-avatar" : request.name
            },
            speechDraftGenerator: { _ in
                environment.makePreviewSpeechDraft()
            },
            speechDraftApplier: { _ in },
            onChoose: { _ in },
            onClose: { [weak self] in
                self?.avatarController = nil
            }
        )

        avatarController = controller
        controller.present()
    }

    @objc private func showGenerationPreview() {
        let controller = generationCoordinator.openGenerationConfig()
        revealAdvancedEditorsIfNeeded(in: controller.window?.contentView)
        controller.present()
    }

    @objc private func quitPreview() {
        NSApplication.shared.terminate(nil)
    }

    private func buildLauncherUI() {
        guard let contentView = launcherWindow.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "Compact UI Preview")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = NSTextField(
            labelWithString: "Open the compact avatar and generation windows without the red/green animation test fixture."
        )
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let avatarButton = NSButton(title: "Open Avatar Window", target: self, action: #selector(showAvatarPreview))
        avatarButton.bezelStyle = .rounded
        avatarButton.translatesAutoresizingMaskIntoConstraints = false

        let generationButton = NSButton(title: "Open Generation Config", target: self, action: #selector(showGenerationPreview))
        generationButton.bezelStyle = .rounded
        generationButton.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quitPreview))
        quitButton.bezelStyle = .rounded
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow = NSStackView(views: [avatarButton, generationButton, quitButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 10
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            buttonRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            buttonRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    private func revealAdvancedEditorsIfNeeded(in rootView: NSView?) {
        guard let rootView else {
            return
        }

        if findTextView(in: rootView, identifier: "generationConfigAuthEditor") != nil {
            return
        }

        guard let advancedButton = findButton(in: rootView, identifier: "generationConfigModeAdvanced") else {
            return
        }

        advancedButton.performClick(nil)
    }

    private func findButton(in rootView: NSView, identifier: String) -> NSButton? {
        if let button = rootView as? NSButton, button.identifier?.rawValue == identifier {
            return button
        }

        for subview in rootView.subviews {
            if let match = findButton(in: subview, identifier: identifier) {
                return match
            }
        }

        return nil
    }

    private func findTextView(in rootView: NSView, identifier: String) -> NSTextView? {
        if let textView = rootView as? NSTextView, textView.identifier?.rawValue == identifier {
            return textView
        }

        for subview in rootView.subviews {
            if let match = findTextView(in: subview, identifier: identifier) {
                return match
            }
        }

        return nil
    }

    private static func makeLauncherWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 170),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Compact UI Preview"
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

private struct CompactUIPreviewEnvironment {
    let rootURL: URL
    let repoRootURL: URL
    let appPaths: AppPaths
    let settingsStore: GenerationSettingsStore
    let themeManager: ThemeManager
    let previewAvatars: [AvatarSummary]

    init(fileManager: FileManager = .default) throws {
        repoRootURL = CompactUIPreviewEnvironment.resolveRepoRootURL(fileManager: fileManager)
        rootURL = fileManager.temporaryDirectory.appendingPathComponent(
            "icu-compact-ui-preview-\(UUID().uuidString)",
            isDirectory: true
        )
        appPaths = AppPaths(rootURL: rootURL)
        try appPaths.ensureDirectories()

        TextCatalog.installShared(try TextCatalog.live(appPaths: appPaths, repoRootURL: repoRootURL, fileManager: fileManager))

        settingsStore = GenerationSettingsStore(appPaths: appPaths, repoRootURL: repoRootURL)
        try settingsStore.save(CompactUIPreviewEnvironment.previewSettings())

        themeManager = try ThemeManager(appPaths: appPaths, settingsStore: settingsStore)
        ThemeManager.installShared(themeManager)

        previewAvatars = try [
            AvatarSummary(
                id: "moss-capybara",
                name: "Moss Capybara",
                style: "terminal pixel",
                previewURL: CompactUIPreviewEnvironment.makePreviewPNG(
                    fileManager: fileManager,
                    directory: rootURL,
                    name: "moss-capybara.png",
                    fill: NSColor(calibratedRed: 0.58, green: 0.86, blue: 0.39, alpha: 1),
                    accent: NSColor(calibratedRed: 0.15, green: 0.22, blue: 0.12, alpha: 1)
                ),
                traits: "steady, calm, screen-friendly",
                tone: "warm"
            ),
            AvatarSummary(
                id: "sand-otter",
                name: "Sand Otter",
                style: "soft retro",
                previewURL: CompactUIPreviewEnvironment.makePreviewPNG(
                    fileManager: fileManager,
                    directory: rootURL,
                    name: "sand-otter.png",
                    fill: NSColor(calibratedRed: 0.89, green: 0.75, blue: 0.47, alpha: 1),
                    accent: NSColor(calibratedRed: 0.27, green: 0.19, blue: 0.10, alpha: 1)
                ),
                traits: "gentle, bright, low-noise",
                tone: "friendly"
            ),
        ]
    }

    func makeGenerationCoordinator() -> GenerationCoordinator {
        let transport = PreviewGenerationTransport()
        let generationService = ThemeGenerationService(
            transport: transport,
            settingsStore: settingsStore,
            themeManager: themeManager
        )
        return GenerationCoordinator(
            settingsStore: settingsStore,
            themeManager: themeManager,
            generationService: generationService
        )
    }

    func makePreviewThemePack() -> ThemePack {
        var pack = PixelTheme.pack
        pack.meta.id = "compact_preview_theme"
        pack.meta.name = "Compact Preview"
        pack.meta.version = 1
        pack.meta.sourcePrompt = "Preview theme for the compact UI launcher."
        pack.tokens.colors.windowBackgroundHex = "#152018"
        pack.tokens.colors.cardBackgroundHex = "#202C22"
        pack.tokens.colors.inputBackgroundHex = "#2A372C"
        pack.tokens.colors.menuBackgroundHex = "#1A241C"
        pack.tokens.colors.accentHex = "#A6E36E"
        pack.tokens.colors.borderHex = "#4E6849"
        pack.tokens.colors.textPrimaryHex = "#EDF6E8"
        pack.tokens.colors.textSecondaryHex = "#B7C8B2"
        return pack
    }

    func makePreviewAvatarDraft() throws -> InlineAvatarPreviewDraft {
        let previewURL = try CompactUIPreviewEnvironment.makePreviewPNG(
            fileManager: .default,
            directory: rootURL,
            name: "inline-avatar-preview.png",
            fill: NSColor(calibratedRed: 0.60, green: 0.84, blue: 0.44, alpha: 1),
            accent: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.11, alpha: 1)
        )

        return InlineAvatarPreviewDraft(
            actionImageURLs: [
                "idle": previewURL,
                "working": previewURL,
                "alert": previewURL,
            ],
            suggestedPersona: "A calm preview persona for compact UI review."
        )
    }

    func makePreviewSpeechDraft() -> SpeechDraft {
        SpeechDraft(
            statusIdle: "Idle and ready",
            statusWorking: "Working through tasks",
            statusFocus: "Deep focus mode",
            statusBreak: "Taking a short break",
            focusEndLight: "Time to look away for a moment.",
            focusEndHeavy: "That was a long stretch. Please rest a bit.",
            stopWorkMessage: "Work session complete.",
            eyeReminder: "Look into the distance and relax your eyes."
        )
    }

    func cleanup(fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: rootURL)
    }

    private static func resolveRepoRootURL(fileManager: FileManager) -> URL {
        if let repoRootPath = ProcessInfo.processInfo.environment["ICU_REPO_ROOT"], !repoRootPath.isEmpty {
            return URL(fileURLWithPath: repoRootPath, isDirectory: true)
        }

        return URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    }

    private static func previewSettings() -> GenerationSettings {
        GenerationSettings(
            activeThemeID: PixelTheme.id,
            textDescription: GenerationCapabilityConfig(
                provider: .ollama,
                baseURL: "http://127.0.0.1:11434/v1",
                model: "qwen2.5:14b",
                auth: [:],
                options: ["temperature": 0.3]
            ),
            animationAvatar: GenerationCapabilityConfig(
                provider: .huggingFace,
                baseURL: "https://api-inference.huggingface.co/models",
                model: "stabilityai/sd3.5-large",
                auth: ["api_key": "hf_preview_token"],
                options: ["guidance_scale": 5.5]
            ),
            codeGeneration: GenerationCapabilityConfig(
                provider: .openAICompatible,
                baseURL: "https://example.com/v1",
                model: "gpt-4.1-mini",
                auth: ["api_key": "sk-preview"],
                options: ["temperature": 0.2, "top_p": 0.9]
            )
        )
    }

    private static func makePreviewPNG(
        fileManager: FileManager,
        directory: URL,
        name: String,
        fill: NSColor,
        accent: NSColor
    ) throws -> URL {
        let url = directory.appendingPathComponent(name, isDirectory: false)
        let size = NSSize(width: 96, height: 96)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        fill.setFill()
        NSBezierPath(roundedRect: NSRect(x: 10, y: 8, width: 76, height: 80), xRadius: 22, yRadius: 22).fill()

        accent.setFill()
        NSBezierPath(ovalIn: NSRect(x: 22, y: 50, width: 18, height: 18)).fill()
        NSBezierPath(ovalIn: NSRect(x: 56, y: 50, width: 18, height: 18)).fill()
        NSBezierPath(roundedRect: NSRect(x: 26, y: 22, width: 44, height: 16), xRadius: 8, yRadius: 8).fill()

        image.unlockFocus()

        guard
            let data = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: data),
            let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw GenerationRouteError.invalidResponse("failed to create compact UI preview image")
        }

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try pngData.write(to: url, options: .atomic)
        return url
    }
}

private struct PreviewGenerationTransport: GenerationTransport {
    func completeJSON(
        prompt: String,
        capability: GenerationCapabilityConfig
    ) throws -> String {
        _ = prompt
        _ = capability
        return "{}"
    }
}
