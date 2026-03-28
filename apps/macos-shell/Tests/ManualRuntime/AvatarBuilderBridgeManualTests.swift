import Foundation

func testAvatarBuilderBridgeParsesOptimizePromptJSON() throws {
    let scriptURL = URL(fileURLWithPath: "/Users/clement/Workspace/icu/tools/testdata/avatar_builder_bridge_stub.py")
    let bridge = AvatarBuilderBridge(scriptURL: scriptURL)

    let prompt = try bridge.optimizePrompt("一只淡定的水豚")

    try expect(prompt.contains("pixel art"), "bridge should parse optimized prompt from JSON")
}

func testAvatarBuilderBridgeSurfacesBridgeFailure() throws {
    let scriptURL = URL(fileURLWithPath: "/Users/clement/Workspace/icu/tools/testdata/avatar_builder_bridge_stub.py")
    let bridge = AvatarBuilderBridge(scriptURL: scriptURL)

    do {
        _ = try bridge.generatePersona("fail")
        throw TestFailure(message: "bridge should throw when stub exits non-zero")
    } catch let error as AvatarBuilderBridgeError {
        try expect(error.localizedDescription.contains("stub persona failure"), "bridge should include stderr detail")
    }
}

func testAvatarBuilderBridgeErrorPrefixCanBeOverriddenByTextCatalog() throws {
    let original = TextCatalog.shared
    defer { TextCatalog.installShared(original) }

    _ = try makeInstalledTextCatalog(
        baseJSON: """
        {
          "errors": {
            "bridge_command_failed_prefix": "Bridge command failed"
          }
        }
        """,
        overrideJSON: """
        {
          "errors": {
            "bridge_command_failed_prefix": "桥接执行失败"
          }
        }
        """
    )

    let error = AvatarBuilderBridgeError.executionFailed(command: "generate-image", details: "timeout")
    try expect(
        error.localizedDescription.contains("桥接执行失败"),
        "bridge error prefix should come from the installed text catalog"
    )
}
