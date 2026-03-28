import Foundation

func validSpeechDraftJSONString() -> String {
    #"""
{
  "status_idle": "空闲待命",
  "status_working": "稳步推进",
  "status_focus": "沉浸专注",
  "status_break": "暂时离开",
  "focus_end_light": "抬头看远一点，再继续。",
  "focus_end_heavy": "已经持续很久了，先完整休息一下。",
  "stop_work_message": "今天先到这里。",
  "eye_reminder": "看向远处，放松一下眼睛。"
}
"""#
}

func testSpeechGenerationServiceUsesTextCapabilityAndReturnsDraft() throws {
    let environment = try makeGenerationEnvironment()
    let transport = StubGenerationTransport(
        results: [
            .success(validSpeechDraftJSONString())
        ]
    )
    let service = SpeechGenerationService(
        transport: transport,
        settingsStore: environment.settingsStore
    )

    let draft = try service.generateSpeechDraft(from: "冷静、简短、像素桌宠")

    try expect(draft.statusIdle == "空闲待命", "speech service should decode the generated idle status")
    try expect(draft.stopWorkMessage == "今天先到这里。", "speech service should decode the generated stop work message")
    try expect(transport.requestedProviders == [.ollama], "speech service should use the text capability only")
    try expect(transport.requestedPrompts.count == 1, "speech service should make exactly one generation request")
}

func testSpeechGenerationServiceRejectsUnsupportedTextProviderBeforeNetworkCall() throws {
    var settings = makeValidGenerationSettings()
    settings.textDescription = GenerationCapabilityConfig(
        provider: .huggingFace,
        baseURL: "https://api-inference.huggingface.co",
        model: "stabilityai/sdxl",
        auth: [:],
        options: [:]
    )

    let transport = StubGenerationTransport(results: [])
    let service = SpeechGenerationService(
        transport: transport,
        settingsStore: try makeGenerationSettingsStore(settings: settings)
    )

    do {
        _ = try service.generateSpeechDraft(from: "像素、冷静、简短")
        throw ManualTestFailure(message: "speech service should reject unsupported text providers")
    } catch let error as GenerationRouteError {
        try expect(
            error == .unsupportedProviderForCapability("text_description", .huggingFace),
            "speech generation should surface capability-aware unsupported provider errors"
        )
        try expect(
            transport.requestedProviders.isEmpty,
            "unsupported capability should fail before making transport calls"
        )
    }
}

func testCopyOverrideStoreAppliesSpeechDraftAndPreservesUnrelatedOverrides() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    let repoRoot = try makeTemporaryDirectory()
    let appPaths = try makeTemporaryAppPaths()
    let baseCopyURL = repoRoot
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("copy", isDirectory: true)
        .appendingPathComponent("base.json", isDirectory: false)
    try writeText(
        at: baseCopyURL,
        contents: """
        {
          "pet": {
            "status_idle": "待机中",
            "stop_work_message": "收工，歇会儿。"
          },
          "errors": {
            "avatar_generate_image_failed": "暂时无法生成形象动作，请检查图像模型配置或鉴权信息。"
          }
        }
        """
    )

    let activeCopyURL = appPaths.configDirectory
        .appendingPathComponent("copy", isDirectory: true)
        .appendingPathComponent("active.json", isDirectory: false)
    try writeText(
        at: activeCopyURL,
        contents: """
        {
          "errors": {
            "avatar_generate_image_failed": "图像动作生成失败，请先检查模型和令牌。"
          }
        }
        """
    )

    TextCatalog.installShared(try TextCatalog.live(appPaths: appPaths, repoRootURL: repoRoot))

    let store = CopyOverrideStore(appPaths: appPaths, repoRootURL: repoRoot)
    let draft = SpeechDraft(
        statusIdle: "空闲待命",
        statusWorking: "稳步推进",
        statusFocus: "沉浸专注",
        statusBreak: "暂时离开",
        focusEndLight: "抬头看远一点，再继续。",
        focusEndHeavy: "已经持续很久了，先完整休息一下。",
        stopWorkMessage: "今天先到这里。",
        eyeReminder: "看向远处，放松一下眼睛。"
    )

    try store.applySpeechDraft(draft)

    let activeRootObject = try loadJSONObject(at: activeCopyURL)
    try expect(
        ((activeRootObject["errors"] as? [String: Any])?["avatar_generate_image_failed"] as? String) == "图像动作生成失败，请先检查模型和令牌。",
        "copy override store should preserve unrelated active copy overrides"
    )
    try expect(
        DesktopPetCopy.statusText(for: .idle) == "空闲待命",
        "copy override store should reload the active catalog for idle status copy"
    )
    try expect(
        DesktopPetCopy.stopWorkMessage() == "今天先到这里。",
        "copy override store should reload the active catalog for transient pet copy"
    )
}
