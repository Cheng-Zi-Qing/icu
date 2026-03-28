import Foundation

enum ThemePackError: Error, Equatable {
    case missingMeta(String)
    case missingToken(String)
    case missingComponent(String)
}

struct ThemePack: Codable, Equatable {
    struct Meta: Codable, Equatable {
        var id: String
        var name: String
        var version: Int
        var sourcePrompt: String?

        init(
            id: String = "",
            name: String = "",
            version: Int = 0,
            sourcePrompt: String? = nil
        ) {
            self.id = id
            self.name = name
            self.version = version
            self.sourcePrompt = sourcePrompt
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case version
            case sourcePrompt = "source_prompt"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 0
            sourcePrompt = try container.decodeIfPresent(String.self, forKey: .sourcePrompt)
        }
    }

    var meta: Meta
    var tokens: ThemeTokens
    var components: ThemeComponentTokens

    init(
        meta: Meta,
        tokens: ThemeTokens,
        components: ThemeComponentTokens
    ) {
        self.meta = meta
        self.tokens = tokens
        self.components = components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta = try container.decodeIfPresent(Meta.self, forKey: .meta) ?? Meta()
        tokens = try container.decodeIfPresent(ThemeTokens.self, forKey: .tokens) ?? ThemeTokens()
        components = try container.decodeIfPresent(ThemeComponentTokens.self, forKey: .components) ?? ThemeComponentTokens()
    }

    func validate() throws {
        guard !meta.id.isEmpty else { throw ThemePackError.missingMeta("id") }
        guard !tokens.colors.menuBackgroundHex.isEmpty else { throw ThemePackError.missingToken("colors.menuBackgroundHex") }
        guard !components.menuRow.padding.isEmpty else { throw ThemePackError.missingComponent("menuRow.padding") }
    }

    func asDefinition() -> ThemeDefinition {
        ThemeDefinition(pack: self)
    }

    static func decodeAndValidate(from data: Data) throws -> ThemePack {
        let decoder = JSONDecoder()
        let pack = try decoder.decode(ThemePack.self, from: data)
        try pack.validate()
        return pack
    }

    static func decodeAndValidate(from json: String) throws -> ThemePack {
        guard let data = json.data(using: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try decodeAndValidate(from: data)
    }
}
