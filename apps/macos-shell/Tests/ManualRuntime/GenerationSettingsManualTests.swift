import Foundation

func writeText(at url: URL, contents: String) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = contents.data(using: .utf8) else {
        throw TestFailure(message: "unable to encode text")
    }
    try data.write(to: url, options: .atomic)
}

func loadJSONObject(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dictionary = object as? [String: Any] else {
        throw TestFailure(message: "expected JSON object at \(url.path)")
    }
    return dictionary
}

func makeTemporaryAppPaths() throws -> AppPaths {
    let root = try makeTemporaryDirectory()
    let paths = AppPaths(rootURL: root)
    try paths.ensureDirectories()
    try FileManager.default.createDirectory(at: themesDirectory(for: paths), withIntermediateDirectories: true)
    return paths
}

func themesDirectory(for paths: AppPaths) -> URL {
    paths.stateDirectory.appendingPathComponent("themes", isDirectory: true)
}

func testGenerationSettingsStoreRoundTripsProviderDefaultsAndCapabilitySelection() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "avatar": {
            "current_id": "seal"
          },
          "generation": {
            "provider_defaults": {
              "openai": {
                "api_key": "sk-openai",
                "base_url": "https://api.openai.com/v1",
                "headers": {
                  "x-org": "design-team"
                }
              },
              "openai-compatible": {
                "api_key": "sk-compat",
                "base_url": "https://proxy.example/v1",
                "headers": {}
              }
            },
            "text_description": {
              "provider": "openai",
              "preset": "gpt-4.1-mini",
              "model": "gpt-4.1-mini",
              "customized": false,
              "options": {
                "temperature": 0.2
              }
            },
            "animation_avatar": {
              "provider": "openai-compatible",
              "preset": "gpt-image-1",
              "model": "gpt-image-1",
              "customized": true,
              "custom": {
                "api_key": "sk-image",
                "base_url": "https://images.example/v1",
                "headers": {
                  "x-tenant": "avatars"
                }
              },
              "options": {}
            },
            "code_generation": {
              "provider": "openai-compatible",
              "preset": "gpt-4.1-mini",
              "model": "gpt-4.1-mini",
              "customized": false,
              "options": {
                "temperature": 0.4
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()
    try expect(
        loaded.textDescription.provider == .openAI,
        "provider-first load should preserve openai provider identity in the model"
    )
    try expect(
        loaded.textDescription.customized == false && loaded.textDescription.custom == nil,
        "provider-first load should keep customized=false capabilities without custom transport"
    )
    try expect(
        loaded.providerDefaults[.openAI]?.baseURL == "https://api.openai.com/v1",
        "provider-first load should expose provider default base_url in model state"
    )
    try expect(
        loaded.textDescription.headers["x-org"] == "design-team",
        "provider-first load should resolve inherited provider-default headers into capability state"
    )
    try store.save(loaded)

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    try expect(
        ((rootObject["avatar"] as? [String: Any])?["current_id"] as? String) == "seal",
        "generation save should preserve avatar.current_id"
    )

    guard let generationBlock = rootObject["generation"] as? [String: Any] else {
        throw TestFailure(message: "generation block should be written")
    }

    let providerDefaults = generationBlock["provider_defaults"] as? [String: Any]
    try expect(
        providerDefaults?["openai"] != nil,
        "provider defaults should round-trip through load/save"
    )
    try expect(
        providerDefaults?["openai-compatible"] != nil,
        "provider defaults should keep per-provider transport defaults"
    )
    try expect(
        providerDefaults?.count == 2,
        "round-trip should not fabricate provider defaults for unconfigured providers"
    )
    let openAIProviderDefault = providerDefaults?["openai"] as? [String: Any]
    try expect(
        openAIProviderDefault?["api_key"] as? String == "sk-openai",
        "provider default api_key should round-trip"
    )
    try expect(
        openAIProviderDefault?["base_url"] as? String == "https://api.openai.com/v1",
        "provider default base_url should round-trip"
    )
    try expect(
        ((openAIProviderDefault?["headers"] as? [String: Any])?["x-org"] as? String) == "design-team",
        "provider default headers should round-trip"
    )
    try expect(
        openAIProviderDefault?["auth"] == nil,
        "provider default auth should remain absent when not provided"
    )
    let openAICompatibleProviderDefault = providerDefaults?["openai-compatible"] as? [String: Any]
    try expect(
        openAICompatibleProviderDefault?["api_key"] as? String == "sk-compat",
        "openai-compatible provider default api_key should round-trip"
    )
    try expect(
        openAICompatibleProviderDefault?["base_url"] as? String == "https://proxy.example/v1",
        "openai-compatible provider default base_url should round-trip"
    )

    guard let textDescription = generationBlock["text_description"] as? [String: Any] else {
        throw TestFailure(message: "text_description block should be written")
    }
    try expect(
        textDescription["provider"] as? String == "openai",
        "capability should persist provider selection"
    )
    try expect(
        textDescription["preset"] as? String == "gpt-4.1-mini",
        "capability should persist model preset"
    )
    try expect(
        textDescription["model"] as? String == "gpt-4.1-mini",
        "capability should persist model id"
    )
    try expect(
        textDescription["customized"] as? Bool == false,
        "capability should persist customized=false when inheriting defaults"
    )
    try expect(
        textDescription["custom"] == nil || textDescription["custom"] is NSNull,
        "customized=false should not persist a capability-level transport override"
    )

    guard let animationAvatar = generationBlock["animation_avatar"] as? [String: Any] else {
        throw TestFailure(message: "animation_avatar block should be written")
    }
    try expect(animationAvatar["customized"] as? Bool == true, "customized=true should persist")
    try expect(animationAvatar["custom"] != nil, "customized=true should preserve custom transport")
}

func testGenerationSettingsStorePersistsCapabilitiesWithoutDroppingAvatarState() throws {
    try testGenerationSettingsStoreRoundTripsProviderDefaultsAndCapabilitySelection()
    try testGenerationSettingsStoreMigratesLegacyCapabilityConfigsToProviderDefaults()
    try testGenerationSettingsStoreDoesNotFabricateProviderDefaultsFromMissingLegacyCapabilities()
    try testGenerationSettingsStoreMigratesLegacyCapabilityShapeWhenProviderDefaultsAlreadyExist()
    try testGenerationSettingsStoreMigratesMixedShapeHeadersOnlyLegacyCapability()
    try testGenerationSettingsStoreMigratesLegacyHeadersIntoProviderDefaultsAndCustomOverrides()
}

func testGenerationSettingsStoreMigratesLegacyCapabilityConfigsToProviderDefaults() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "generation": {
            "text_description": {
              "provider": "openai-compatible",
              "base_url": "https://proxy.example/v1",
              "model": "gpt-4.1-mini",
              "auth": {
                "api_key": "sk-shared"
              },
              "options": {
                "temperature": 0.2
              }
            },
            "animation_avatar": {
              "provider": "huggingface",
              "base_url": "https://api-inference.huggingface.co",
              "model": "stabilityai/stable-diffusion-xl-base-1.0",
              "auth": {
                "token": "hf-shared"
              },
              "options": {}
            },
            "code_generation": {
              "provider": "openai-compatible",
              "base_url": "https://proxy-alt.example/v1",
              "model": "gpt-4.1-mini",
              "auth": {
                "api_key": "sk-shared"
              },
              "options": {
                "temperature": 0.6
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()
    try expect(
        loaded.textDescription.provider == .openAICompatible,
        "legacy migration load should keep provider identity for configured legacy capability"
    )
    try expect(
        loaded.codeGeneration.customized == true,
        "legacy migration load should mark differing provider transport as customized"
    )
    try store.save(loaded)

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    guard let generationBlock = rootObject["generation"] as? [String: Any] else {
        throw TestFailure(message: "generation block should be written")
    }
    guard let providerDefaults = generationBlock["provider_defaults"] as? [String: Any] else {
        throw TestFailure(message: "legacy configs should migrate into generation.provider_defaults")
    }

    try expect(
        providerDefaults["openai-compatible"] != nil,
        "legacy migration should create openai-compatible provider defaults"
    )
    try expect(
        providerDefaults["huggingface"] != nil,
        "legacy migration should create huggingface provider defaults"
    )
    try expect(
        providerDefaults.count == 2,
        "legacy migration should only create provider defaults for configured legacy providers"
    )
    let openAICompatibleProviderDefault = providerDefaults["openai-compatible"] as? [String: Any]
    try expect(
        openAICompatibleProviderDefault?["api_key"] as? String == "sk-shared",
        "legacy migration should lift api_key into provider defaults"
    )
    try expect(
        openAICompatibleProviderDefault?["base_url"] as? String == "https://proxy.example/v1",
        "legacy migration should lift first-seen base_url into provider defaults"
    )
    try expect(
        (openAICompatibleProviderDefault?["headers"] as? [String: Any])?.isEmpty == true,
        "legacy migration should write empty headers map when no legacy headers exist"
    )
    let huggingFaceProviderDefault = providerDefaults["huggingface"] as? [String: Any]
    try expect(
        huggingFaceProviderDefault?["api_key"] as? String == "",
        "legacy migration should only set api_key when legacy auth contains api_key"
    )
    try expect(
        huggingFaceProviderDefault?["base_url"] as? String == "https://api-inference.huggingface.co",
        "legacy migration should lift huggingface base_url into provider defaults"
    )
    try expect(
        ((huggingFaceProviderDefault?["auth"] as? [String: Any])?["token"] as? String) == "hf-shared",
        "legacy migration should preserve non-api_key auth payloads under provider defaults.auth"
    )

    let textDescription = generationBlock["text_description"] as? [String: Any] ?? [:]
    let codeGeneration = generationBlock["code_generation"] as? [String: Any] ?? [:]
    try expect(
        textDescription["customized"] as? Bool == false,
        "matching legacy transport should migrate as customized=false"
    )
    try expect(
        textDescription["custom"] == nil || textDescription["custom"] is NSNull,
        "customized=false should omit capability-level custom transport"
    )
    try expect(
        codeGeneration["customized"] as? Bool == true,
        "differing legacy transport should migrate as customized=true"
    )
    try expect(
        (codeGeneration["custom"] as? [String: Any])?["base_url"] as? String == "https://proxy-alt.example/v1",
        "legacy transport differences should be preserved under capability custom override"
    )
}

func testGenerationSettingsStoreDoesNotFabricateProviderDefaultsFromMissingLegacyCapabilities() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "generation": {
            "text_description": {
              "provider": "openai-compatible",
              "base_url": "https://proxy.example/v1",
              "model": "gpt-4.1-mini",
              "auth": {
                "api_key": "sk-shared"
              },
              "options": {
                "temperature": 0.2
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()
    try expect(
        loaded.animationAvatar.customized == false && loaded.animationAvatar.custom == nil,
        "missing legacy capability should stay missing/blank without fabricated custom override"
    )
    try expect(
        loaded.codeGeneration.customized == false && loaded.codeGeneration.custom == nil,
        "missing legacy capability should not become customized due to another capability default"
    )
    try store.save(loaded)

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    let generationBlock = rootObject["generation"] as? [String: Any] ?? [:]
    let providerDefaults = generationBlock["provider_defaults"] as? [String: Any] ?? [:]

    try expect(
        providerDefaults.count == 1,
        "partial legacy migration should not create provider defaults for missing capabilities"
    )
    try expect(
        providerDefaults["openai-compatible"] != nil,
        "partial legacy migration should retain the configured provider default"
    )
    try expect(
        providerDefaults["ollama"] == nil && providerDefaults["huggingface"] == nil,
        "partial legacy migration should not fabricate ollama or huggingface defaults"
    )
}

func testGenerationSettingsStoreMigratesLegacyCapabilityShapeWhenProviderDefaultsAlreadyExist() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "generation": {
            "provider_defaults": {
              "openai-compatible": {
                "api_key": "sk-default",
                "base_url": "https://proxy.default/v1",
                "headers": {
                  "x-default": "yes"
                }
              }
            },
            "text_description": {
              "provider": "openai-compatible",
              "base_url": "https://proxy.custom/v1",
              "model": "gpt-4.1-mini",
              "auth": {
                "api_key": "sk-custom"
              },
              "options": {
                "temperature": 0.2
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()

    try expect(
        loaded.textDescription.provider == .openAICompatible,
        "hybrid read-path should preserve provider identity for legacy-shaped capability blocks"
    )
    try expect(
        loaded.textDescription.customized == true,
        "hybrid read-path should migrate legacy-shaped capability blocks into customized=true when transport differs"
    )
    try expect(
        loaded.textDescription.baseURL == "https://proxy.custom/v1",
        "hybrid read-path should retain legacy base_url instead of discarding it when provider_defaults exists"
    )
    try expect(
        loaded.textDescription.auth["api_key"] == "sk-custom",
        "hybrid read-path should retain legacy auth instead of discarding it when provider_defaults exists"
    )
    try expect(
        loaded.textDescription.headers["x-default"] == nil,
        "hybrid read-path should use custom transport headers for customized capabilities"
    )
    try expect(
        loaded.textDescription.custom?.headers.isEmpty == true,
        "hybrid read-path should preserve legacy capability transport in custom override form"
    )

    try store.save(loaded)

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    let generationBlock = rootObject["generation"] as? [String: Any] ?? [:]
    let textDescription = generationBlock["text_description"] as? [String: Any] ?? [:]
    try expect(
        textDescription["customized"] as? Bool == true,
        "hybrid read-path save should persist migrated legacy capability as customized"
    )
    try expect(
        (textDescription["custom"] as? [String: Any])?["base_url"] as? String == "https://proxy.custom/v1",
        "hybrid read-path save should persist legacy base_url under custom override"
    )
    try expect(
        ((textDescription["custom"] as? [String: Any])?["auth"] as? [String: Any])?["api_key"] as? String == "sk-custom",
        "hybrid read-path save should persist legacy auth under custom override"
    )
}

func testGenerationSettingsStoreMigratesMixedShapeHeadersOnlyLegacyCapability() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "generation": {
            "provider_defaults": {
              "openai-compatible": {
                "api_key": "",
                "base_url": "",
                "headers": {}
              }
            },
            "text_description": {
              "provider": "openai-compatible",
              "model": "gpt-4.1-mini",
              "headers": {
                "x-legacy": "headers-only"
              },
              "options": {
                "temperature": 0.2
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()
    try expect(
        loaded.textDescription.customized == true,
        "mixed-shape headers-only legacy block should migrate as customized=true"
    )
    try expect(
        loaded.textDescription.custom?.headers["x-legacy"] == "headers-only",
        "mixed-shape headers-only legacy block should preserve legacy headers in custom transport"
    )

    try store.save(loaded)
    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    let generationBlock = rootObject["generation"] as? [String: Any] ?? [:]
    let textDescription = generationBlock["text_description"] as? [String: Any] ?? [:]
    try expect(
        (((textDescription["custom"] as? [String: Any])?["headers"] as? [String: Any])?["x-legacy"] as? String) == "headers-only",
        "mixed-shape headers-only legacy block should persist migrated custom headers on save"
    )
}

func testGenerationSettingsStoreMigratesLegacyHeadersIntoProviderDefaultsAndCustomOverrides() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "generation": {
            "text_description": {
              "provider": "openai-compatible",
              "base_url": "https://proxy.example/v1",
              "model": "gpt-4.1-mini",
              "auth": {
                "api_key": "sk-shared"
              },
              "headers": {
                "x-team": "foundation"
              },
              "options": {
                "temperature": 0.2
              }
            },
            "code_generation": {
              "provider": "openai-compatible",
              "base_url": "https://proxy.example/v1",
              "model": "gpt-4.1-mini",
              "auth": {
                "api_key": "sk-shared"
              },
              "headers": {
                "x-team": "codegen"
              },
              "options": {
                "temperature": 0.6
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()
    try expect(
        loaded.providerDefaults[.openAICompatible]?.headers["x-team"] == "foundation",
        "legacy migration should preserve first-seen legacy headers under provider defaults"
    )
    try expect(
        loaded.textDescription.customized == false,
        "matching legacy headers should migrate as customized=false"
    )
    try expect(
        loaded.codeGeneration.customized == true,
        "header differences should migrate as customized=true"
    )
    try expect(
        loaded.codeGeneration.custom?.headers["x-team"] == "codegen",
        "header differences should be preserved in capability custom override headers"
    )

    try store.save(loaded)

    let rootObject = try loadJSONObject(at: root.appendingPathComponent("config/settings.json"))
    let generationBlock = rootObject["generation"] as? [String: Any] ?? [:]
    let providerDefaults = generationBlock["provider_defaults"] as? [String: Any] ?? [:]
    let compatDefault = providerDefaults["openai-compatible"] as? [String: Any] ?? [:]
    try expect(
        ((compatDefault["headers"] as? [String: Any])?["x-team"] as? String) == "foundation",
        "saved provider defaults should keep migrated legacy headers"
    )
    let codeGeneration = generationBlock["code_generation"] as? [String: Any] ?? [:]
    try expect(
        (((codeGeneration["custom"] as? [String: Any])?["headers"] as? [String: Any])?["x-team"] as? String) == "codegen",
        "saved customized capability should keep migrated custom headers"
    )
}

func testGenerationSettingsStoreFallsBackToRepoSettingsAndMigratesWritesToAppSupport() throws {
    let repoRoot = try makeTemporaryDirectory()
    let appRoot = try makeTemporaryDirectory()
    defer {
        try? FileManager.default.removeItem(at: repoRoot)
        try? FileManager.default.removeItem(at: appRoot)
    }

    try writeText(
        at: repoRoot.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "avatar": {
            "current_id": "seal",
            "custom_avatars": []
          },
          "generation": {
            "provider_defaults": {
              "ollama": {
                "api_key": "",
                "base_url": "http://localhost:11434",
                "headers": {}
              }
            },
            "text_description": {
              "provider": "ollama",
              "preset": "qwen3.5:35b",
              "model": "qwen3.5:35b",
              "customized": false,
              "options": {
                "temperature": 0.7
              }
            }
          }
        }
        """#
    )

    let appPaths = AppPaths(rootURL: appRoot)
    try appPaths.ensureDirectories()
    let store = GenerationSettingsStore(appPaths: appPaths, repoRootURL: repoRoot)

    let loaded = try store.load()
    try expect(
        loaded.textDescription.model == "qwen3.5:35b",
        "store should fall back to repo settings when app support settings are missing"
    )

    try store.save(
        GenerationSettings(
            activeThemeID: "pixel_default",
            providerDefaults: loaded.providerDefaults,
            textDescription: loaded.textDescription,
            animationAvatar: GenerationCapabilityConfig(
                provider: .huggingFace,
                baseURL: "https://api-inference.huggingface.co",
                model: "stabilityai/stable-diffusion-xl-base-1.0",
                auth: ["token": "hf_live"],
                options: [:]
            ),
            codeGeneration: GenerationCapabilityConfig(
                provider: .openAICompatible,
                baseURL: "https://example.invalid/v1",
                model: "gpt-4.1-mini",
                auth: [:],
                options: [:]
            )
        )
    )

    let appSettingsURL = appRoot
        .appendingPathComponent("config", isDirectory: true)
        .appendingPathComponent("settings.json", isDirectory: false)
    let migratedRoot = try loadJSONObject(at: appSettingsURL)
    let repoRootObject = try loadJSONObject(at: repoRoot.appendingPathComponent("config/settings.json"))

    try expect(
        ((migratedRoot["avatar"] as? [String: Any])?["current_id"] as? String) == "seal",
        "saving via app support store should preserve repo-backed avatar defaults during migration"
    )
    try expect(
        ((((migratedRoot["generation"] as? [String: Any])?["animation_avatar"] as? [String: Any])?["model"] as? String) == "stabilityai/stable-diffusion-xl-base-1.0"),
        "saving via app support store should write migrated settings into Application Support"
    )
    try expect(
        (((migratedRoot["generation"] as? [String: Any])?["provider_defaults"] as? [String: Any])?["ollama"] != nil),
        "saving via app support store should keep provider defaults in new generation shape"
    )
    try expect(
        repoRootObject["theme"] == nil,
        "migration writes should not mutate the repo-backed settings file"
    )
}

func testGenerationSettingsStoreIgnoresBooleanOptionsWhenLoading() throws {
    let root = try makeTemporaryDirectory()
    try writeText(
        at: root.appendingPathComponent("config/settings.json"),
        contents: #"""
        {
          "generation": {
            "text_description": {
              "provider": "ollama",
              "base_url": "http://localhost:11434",
              "model": "qwen3.5:35b",
              "auth": {},
              "options": {
                "temperature": 0.7,
                "stream": true
              }
            }
          }
        }
        """#
    )

    let store = GenerationSettingsStore(repoRootURL: root)
    let loaded = try store.load()

    try expect(
        loaded.textDescription.options["temperature"] == 0.7,
        "store should keep real numeric options when loading settings"
    )
    try expect(
        loaded.textDescription.options["stream"] == nil,
        "store should ignore boolean options instead of coercing them to 1.0 or 0.0"
    )
}
