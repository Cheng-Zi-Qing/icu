import Foundation

struct ManualTestFailure: Error {
    let message: String
}

final class GenerationHTTPTestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var capturedRequests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw ManualTestFailure(message: "missing GenerationHTTPTestURLProtocol handler")
            }
            let (response, data) = try handler(request)
            Self.capturedRequests.append(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
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

    try expect(
        GenerationCapabilityKind.textDescription.allowedProviders == [.openAI, .anthropic, .ollama, .openAICompatible],
        "text description capability should support OpenAI, Anthropic, Ollama, and OpenAI-compatible transports"
    )
    try expect(
        GenerationCapabilityKind.codeGeneration.allowedProviders == [.openAI, .anthropic, .ollama, .openAICompatible],
        "code generation capability should support OpenAI, Anthropic, Ollama, and OpenAI-compatible transports"
    )
    try expect(
        GenerationCapabilityKind.animationAvatar.allowedProviders == [.openAI, .huggingFace, .openAICompatible],
        "avatar capability should support OpenAI, HuggingFace, and OpenAI-compatible transports"
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

    try testGenerationHTTPClientBuildsAnthropicMessagesPayloadAndHeaders()
    try testGenerationHTTPClientUsesChatCompletionsForOpenAIAndOpenAICompatible()
    try testGenerationHTTPClientUsesProviderSpecificEndpointsForConnectionChecks()
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

func testGenerationHTTPClientBuildsAnthropicMessagesPayloadAndHeaders() throws {
    GenerationHTTPTestURLProtocol.capturedRequests = []
    GenerationHTTPTestURLProtocol.handler = { request in
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let body = #"{"content":[{"type":"text","text":"{\"name\":\"ok\"}"}]}"#
        return (response, Data(body.utf8))
    }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GenerationHTTPTestURLProtocol.self]
    let client = GenerationHTTPClient(session: URLSession(configuration: configuration))

    let capability = GenerationCapabilityConfig(
        provider: .anthropic,
        baseURL: "https://api.anthropic.com/v1",
        model: "claude-3-7-sonnet-latest",
        auth: ["api_key": "anthropic-test-key"],
        options: ["temperature": 0.4]
    )

    _ = try client.completeJSON(prompt: "Return JSON", capability: capability)

    guard let request = GenerationHTTPTestURLProtocol.capturedRequests.last else {
        throw ManualTestFailure(message: "anthropic transport should issue exactly one request")
    }
    try expect(
        request.url?.absoluteString == "https://api.anthropic.com/v1/messages",
        "anthropic transport should call the native messages endpoint"
    )
    try expect(
        request.value(forHTTPHeaderField: "x-api-key") == "anthropic-test-key",
        "anthropic transport should send x-api-key from resolved auth"
    )
    try expect(
        request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01",
        "anthropic transport should send anthropic-version header"
    )
    try expect(
        request.value(forHTTPHeaderField: "Authorization") == nil,
        "anthropic transport should not send Authorization when auth source is api_key"
    )

    let bodyData = try expectHTTPBodyData(request: request, message: "anthropic transport should include request JSON payload")
    let bodyObject = try expectJSONObject(bodyData, message: "anthropic payload should be valid JSON object")
    let messages = bodyObject["messages"] as? [[String: Any]]
    try expect(messages?.count == 1, "anthropic payload should include exactly one user message")
    try expect(
        messages?.first?["role"] as? String == "user",
        "anthropic payload should encode the prompt as a user message"
    )
}

func testGenerationHTTPClientUsesChatCompletionsForOpenAIAndOpenAICompatible() throws {
    GenerationHTTPTestURLProtocol.capturedRequests = []
    GenerationHTTPTestURLProtocol.handler = { request in
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let body = #"{"choices":[{"message":{"content":"{\"ok\":true}"}}]}"#
        return (response, Data(body.utf8))
    }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GenerationHTTPTestURLProtocol.self]
    let client = GenerationHTTPClient(session: URLSession(configuration: configuration))

    _ = try client.completeJSON(
        prompt: "Return JSON",
        capability: GenerationCapabilityConfig(
            provider: .openAI,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4.1-mini",
            auth: ["api_key": "openai-test-key"],
            options: [:]
        )
    )
    _ = try client.completeJSON(
        prompt: "Return JSON",
        capability: GenerationCapabilityConfig(
            provider: .openAICompatible,
            baseURL: "https://example.invalid/v1",
            model: "provider-model",
            auth: ["api_key": "compat-key"],
            options: [:]
        )
    )

    let urls = GenerationHTTPTestURLProtocol.capturedRequests.compactMap { $0.url?.absoluteString }
    try expect(
        urls == [
            "https://api.openai.com/v1/chat/completions",
            "https://example.invalid/v1/chat/completions",
        ],
        "OpenAI and OpenAI-compatible providers should both resolve to chat/completions"
    )
}

func testGenerationHTTPClientUsesProviderSpecificEndpointsForConnectionChecks() throws {
    GenerationHTTPTestURLProtocol.capturedRequests = []
    GenerationHTTPTestURLProtocol.handler = { request in
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, Data())
    }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GenerationHTTPTestURLProtocol.self]
    let client = GenerationHTTPClient(session: URLSession(configuration: configuration))

    try client.testConnection(
        provider: .openAI,
        defaults: GenerationProviderDefaultConfig(
            apiKey: "openai-test-key",
            baseURL: "https://api.openai.com/v1"
        )
    )
    try client.testConnection(
        provider: .anthropic,
        defaults: GenerationProviderDefaultConfig(
            apiKey: "anthropic-test-key",
            baseURL: "https://api.anthropic.com/v1"
        )
    )
    try client.testConnection(
        provider: .ollama,
        defaults: GenerationProviderDefaultConfig(
            baseURL: "http://localhost:11434"
        )
    )

    let requests = GenerationHTTPTestURLProtocol.capturedRequests
    let urls = requests.compactMap { $0.url?.absoluteString }
    try expect(
        urls == [
            "https://api.openai.com/v1/models",
            "https://api.anthropic.com/v1/models",
            "http://localhost:11434/api/tags",
        ],
        "connection checks should use provider-specific endpoints"
    )
    try expect(
        requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer openai-test-key",
        "OpenAI connection checks should send bearer auth"
    )
    try expect(
        requests.dropFirst().first?.value(forHTTPHeaderField: "x-api-key") == "anthropic-test-key",
        "Anthropic connection checks should send x-api-key"
    )
    try expect(
        requests.dropFirst().first?.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01",
        "Anthropic connection checks should send anthropic-version"
    )
}

private func expectHTTPBodyData(request: URLRequest, message: String) throws -> Data {
    if let data = request.httpBody {
        return data
    }
    if let stream = request.httpBodyStream {
        return try readHTTPBodyStream(stream)
    }
    throw ManualTestFailure(message: message)
}

private func expectJSONObject(_ data: Data, message: String) throws -> [String: Any] {
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
        throw ManualTestFailure(message: message)
    }
    return dictionary
}

private func readHTTPBodyStream(_ stream: InputStream) throws -> Data {
    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)

    while stream.hasBytesAvailable {
        let bytesRead = stream.read(&buffer, maxLength: bufferSize)
        if bytesRead < 0 {
            throw ManualTestFailure(message: "failed to read HTTP body stream")
        }
        if bytesRead == 0 {
            break
        }
        data.append(buffer, count: bytesRead)
    }

    return data
}
