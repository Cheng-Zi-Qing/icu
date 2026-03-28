import Foundation

struct ManualTestFailure: Error {
    let message: String
}

final class StubGenerationTransport: GenerationTransport {
    private let results: [Result<String, Error>]
    private var nextResultIndex = 0

    private(set) var requestedProviders: [GenerationCapabilityProvider] = []
    private(set) var requestedPrompts: [String] = []

    init(results: [Result<String, Error>]) {
        self.results = results
    }

    func completeJSON(prompt: String, capability: GenerationCapabilityConfig) throws -> String {
        requestedProviders.append(capability.provider)
        requestedPrompts.append(prompt)

        guard nextResultIndex < results.count else {
            throw ManualTestFailure(message: "stub exhausted")
        }

        defer { nextResultIndex += 1 }
        switch results[nextResultIndex] {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

func validThemePackJSONString(id: String) -> String {
    return #"""
{
  "meta": {
    "id": "\#(id)",
    "name": "Generated",
    "version": 1,
    "source_prompt": "vibe"
  },
  "tokens": {
    "colors": {
      "menu_background_hex": "#1F2233"
    }
  },
  "components": {
    "menu_row": {
      "padding": "8"
    }
  }
}
"""#
}

func makeValidGenerationSettings() -> GenerationSettings {
    GenerationSettings(
        activeThemeID: nil,
        textDescription: GenerationCapabilityConfig(
            provider: .ollama,
            baseURL: "http://localhost:11434",
            model: "ollama-mini",
            auth: [:],
            options: [:]
        ),
        animationAvatar: GenerationCapabilityConfig(
            provider: .huggingFace,
            baseURL: "",
            model: "",
            auth: [:],
            options: [:]
        ),
        codeGeneration: GenerationCapabilityConfig(
            provider: .openAICompatible,
            baseURL: "https://api.example.invalid/v1",
            model: "gpt-4.1-mini",
            auth: [:],
            options: [:]
        )
    )
}

func makeGenerationSettingsStore(settings: GenerationSettings = makeValidGenerationSettings()) throws -> GenerationSettingsStore {
    let repoRoot = try makeTemporaryDirectory()
    try FileManager.default.createDirectory(at: repoRoot.appendingPathComponent("config", isDirectory: true), withIntermediateDirectories: true)

    let store = GenerationSettingsStore(repoRootURL: repoRoot)
    try store.save(settings)
    return store
}

func makeGenerationEnvironment(settings: GenerationSettings = makeValidGenerationSettings()) throws -> (
    settingsStore: GenerationSettingsStore,
    themeManager: ThemeManager
) {
    let repoRoot = try makeTemporaryDirectory()
    let paths = AppPaths(rootURL: repoRoot)
    try paths.ensureDirectories()

    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    try settingsStore.save(settings)

    let themeManager = try ThemeManager(appPaths: paths, settingsStore: settingsStore)
    return (settingsStore: settingsStore, themeManager: themeManager)
}

func makeThemeManagerWithPixelDefault() throws -> ThemeManager {
    let repoRoot = try makeTemporaryDirectory()
    let paths = AppPaths(rootURL: repoRoot)
    try paths.ensureDirectories()
    let settingsStore = GenerationSettingsStore(repoRootURL: repoRoot)
    let manager = try ThemeManager(appPaths: paths, settingsStore: settingsStore)
    ThemeManager.installShared(manager)
    return manager
}

func makeThemeManager() throws -> ThemeManager {
    try makeThemeManagerWithPixelDefault()
}

func testGenerationCapabilityRouterReturnsAnimationAvatarCapability() throws {
    var settings = makeValidGenerationSettings()
    settings.animationAvatar = GenerationCapabilityConfig(
        provider: .huggingFace,
        baseURL: "https://api-inference.huggingface.co",
        model: "stabilityai/stable-diffusion-xl-base-1.0",
        auth: [:],
        options: [:]
    )

    let router = GenerationCapabilityRouter(settingsStore: try makeGenerationSettingsStore(settings: settings))

    let capability = try router.capability(for: .animationAvatar)

    try expect(
        capability.provider == .huggingFace,
        "capability router should return the configured animation avatar provider"
    )
}

func testGenerationCapabilityRouterRejectsUnsupportedTextDescriptionProvider() throws {
    var settings = makeValidGenerationSettings()
    settings.textDescription = GenerationCapabilityConfig(
        provider: .huggingFace,
        baseURL: "https://api-inference.huggingface.co",
        model: "stabilityai/sdxl",
        auth: [:],
        options: [:]
    )

    let router = GenerationCapabilityRouter(settingsStore: try makeGenerationSettingsStore(settings: settings))

    do {
        _ = try router.capability(for: .textDescription)
        throw ManualTestFailure(message: "router should reject unsupported text provider")
    } catch let error as GenerationRouteError {
        try expect(
            error == .unsupportedProviderForCapability("text_description", .huggingFace),
            "router should describe unsupported provider using the capability name"
        )
    }
}

func testThemeGenerationServiceUsesTextThenCodeCapabilities() throws {
    let environment = try makeGenerationEnvironment()
    let transport = StubGenerationTransport(
        results: [
            .success(#"{\"name\":\"Moss Pixel\",\"summary\":\"掌机感、苔藓绿、低饱和\"}"#),
            .success(validThemePackJSONString(id: "moss_pixel"))
        ]
    )
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: environment.settingsStore,
        themeManager: environment.themeManager
    )

    let applied = try service.generateAndApplyTheme(from: "像素风、掌机、苔藓绿")

    try expect(applied.meta.id == "moss_pixel", "service should apply generated theme pack")
    try expect(transport.requestedProviders == [.ollama, .openAICompatible], "service should call text capability before code capability")
    try expect(environment.themeManager.currentTheme.id == "moss_pixel", "service should activate generated theme in theme manager")
    let activeThemeID = try environment.settingsStore.loadActiveThemeID()
    try expect(activeThemeID == "moss_pixel", "service should persist generated active theme ID")
}

func testThemeGenerationServiceCanGenerateDraftWithoutApplying() throws {
    let environment = try makeGenerationEnvironment()
    let transport = StubGenerationTransport(
        results: [
            .success(#"{\"name\":\"Moss Pixel\",\"summary\":\"掌机感、苔藓绿、低饱和\"}"#),
            .success(validThemePackJSONString(id: "moss_pixel_draft"))
        ]
    )
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: environment.settingsStore,
        themeManager: environment.themeManager
    )

    let draft = try service.generateThemeDraft(from: "像素风、掌机、苔藓绿")

    try expect(draft.meta.id == "moss_pixel_draft", "service should return the generated draft theme pack")
    try expect(
        environment.themeManager.currentTheme.id == "pixel_default",
        "draft generation must not activate the generated theme before apply"
    )
    let activeThemeID = try environment.settingsStore.loadActiveThemeID()
    try expect(activeThemeID == nil, "draft generation must not persist an active theme ID")
    try expect(
        transport.requestedProviders == [.ollama, .openAICompatible],
        "draft generation should still call text capability before code capability"
    )
}

func testThemeGenerationServiceKeepsCurrentThemeWhenGeneratedPackIsInvalid() throws {
    let transport = StubGenerationTransport(
        results: [
            .success(#"{\"name\":\"Broken Theme\",\"summary\":\"bad\"}"#),
            .success(#"{\"meta\":{\"id\":\"broken\",\"name\":\"Broken\",\"version\":1},\"tokens\":{},\"components\":{}}"#)
        ]
    )
    let themeManager = try makeThemeManagerWithPixelDefault()
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: try makeGenerationSettingsStore(),
        themeManager: themeManager
    )

    do {
        _ = try service.generateAndApplyTheme(from: "损坏主题")
        throw ManualTestFailure(message: "service should throw on invalid generated pack")
    } catch {
        try expect(themeManager.currentTheme.id == "pixel_default", "invalid theme generation must not replace current theme")
        try expect(transport.requestedProviders == [.ollama, .openAICompatible], "invalid generation attempt should still call both capabilities")
    }
}

func testThemeGenerationServiceRejectsEmptyVibeBeforeNetworkCall() throws {
    let transport = StubGenerationTransport(results: [])
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: try makeGenerationSettingsStore(),
        themeManager: try makeThemeManager()
    )

    do {
        _ = try service.generateAndApplyTheme(from: " \n\t ")
        throw ManualTestFailure(message: "service should reject empty vibe")
    } catch let error as GenerationRouteError {
        try expect(error == .emptyVibe, "empty vibe should throw GenerationRouteError.emptyVibe")
        try expect(transport.requestedProviders.isEmpty, "empty vibe should fail before making transport calls")
    }
}

func testThemeGenerationServiceThrowsRecoverableErrorForMissingCapabilityConfig() throws {
    var settings = makeValidGenerationSettings()
    settings.codeGeneration = .emptyCodeGeneration

    let transport = StubGenerationTransport(results: [])
    let service = ThemeGenerationService(
        transport: transport,
        settingsStore: try makeGenerationSettingsStore(settings: settings),
        themeManager: try makeThemeManager()
    )

    do {
        _ = try service.generateAndApplyTheme(from: "像素风")
        throw ManualTestFailure(message: "service should fail when code generation capability is missing")
    } catch let error as GenerationRouteError {
        try expect(
            error == .missingCapabilityConfig("code_generation"),
            "missing capability should throw GenerationRouteError.missingCapabilityConfig(code_generation)"
        )
        try expect(transport.requestedProviders.isEmpty, "missing capability should fail before transport calls")
    }
}

func testGenerationRouteErrorEmptyVibeUsesCopyCatalogMessage() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "errors": {
            "empty_vibe": "Please enter a vibe description before generating a theme."
          }
        }
        """,
        overrideJSON: """
        {
          "errors": {
            "empty_vibe": "先输入主题 prompt 再生成。"
          }
        }
        """
    )

    try expect(
        GenerationRouteError.emptyVibe.localizedDescription == "先输入主题 prompt 再生成。",
        "generation route error should resolve its message via the installed text catalog"
    )
}
