import Foundation

struct ThemeDefinition: Codable, Equatable {
    var id: String
    var name: String
    var version: Int
    var sourcePrompt: String?
    var tokens: ThemeTokens
    var components: ThemeComponentTokens

    init(
        id: String,
        name: String,
        version: Int,
        sourcePrompt: String? = nil,
        tokens: ThemeTokens,
        components: ThemeComponentTokens
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.sourcePrompt = sourcePrompt
        self.tokens = tokens
        self.components = components
    }

    init(pack: ThemePack) {
        self.init(
            id: pack.meta.id,
            name: pack.meta.name,
            version: pack.meta.version,
            sourcePrompt: pack.meta.sourcePrompt,
            tokens: pack.tokens,
            components: pack.components
        )
    }
}

struct ThemeTokens: Codable, Equatable {
    var colors: ColorTokens
    var typography: TypographyTokens
    var surface: SurfaceTokens
    var motion: MotionTokens
    var assets: AssetTokens

    init(
        colors: ColorTokens = ColorTokens(),
        typography: TypographyTokens = TypographyTokens(),
        surface: SurfaceTokens = SurfaceTokens(),
        motion: MotionTokens = MotionTokens(),
        assets: AssetTokens = AssetTokens()
    ) {
        self.colors = colors
        self.typography = typography
        self.surface = surface
        self.motion = motion
        self.assets = assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        colors = try container.decodeIfPresent(ColorTokens.self, forKey: .colors) ?? ColorTokens()
        typography = try container.decodeIfPresent(TypographyTokens.self, forKey: .typography) ?? TypographyTokens()
        surface = try container.decodeIfPresent(SurfaceTokens.self, forKey: .surface) ?? SurfaceTokens()
        motion = try container.decodeIfPresent(MotionTokens.self, forKey: .motion) ?? MotionTokens()
        assets = try container.decodeIfPresent(AssetTokens.self, forKey: .assets) ?? AssetTokens()
    }
}

struct ColorTokens: Codable, Equatable {
    var windowBackgroundHex: String
    var cardBackgroundHex: String
    var inputBackgroundHex: String
    var menuBackgroundHex: String
    var accentHex: String
    var borderHex: String
    var textPrimaryHex: String
    var textSecondaryHex: String
    var dangerHex: String
    var overlayHex: String

    init(
        windowBackgroundHex: String = "",
        cardBackgroundHex: String = "",
        inputBackgroundHex: String = "",
        menuBackgroundHex: String = "",
        accentHex: String = "",
        borderHex: String = "",
        textPrimaryHex: String = "",
        textSecondaryHex: String = "",
        dangerHex: String = "",
        overlayHex: String = ""
    ) {
        self.windowBackgroundHex = windowBackgroundHex
        self.cardBackgroundHex = cardBackgroundHex
        self.inputBackgroundHex = inputBackgroundHex
        self.menuBackgroundHex = menuBackgroundHex
        self.accentHex = accentHex
        self.borderHex = borderHex
        self.textPrimaryHex = textPrimaryHex
        self.textSecondaryHex = textSecondaryHex
        self.dangerHex = dangerHex
        self.overlayHex = overlayHex
    }

    enum CodingKeys: String, CodingKey {
        case windowBackgroundHex = "window_background_hex"
        case cardBackgroundHex = "card_background_hex"
        case inputBackgroundHex = "input_background_hex"
        case menuBackgroundHex = "menu_background_hex"
        case accentHex = "accent_hex"
        case borderHex = "border_hex"
        case textPrimaryHex = "text_primary_hex"
        case textSecondaryHex = "text_secondary_hex"
        case dangerHex = "danger_hex"
        case overlayHex = "overlay_hex"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windowBackgroundHex = try container.decodeIfPresent(String.self, forKey: .windowBackgroundHex) ?? ""
        cardBackgroundHex = try container.decodeIfPresent(String.self, forKey: .cardBackgroundHex) ?? ""
        inputBackgroundHex = try container.decodeIfPresent(String.self, forKey: .inputBackgroundHex) ?? ""
        menuBackgroundHex = try container.decodeIfPresent(String.self, forKey: .menuBackgroundHex) ?? ""
        accentHex = try container.decodeIfPresent(String.self, forKey: .accentHex) ?? ""
        borderHex = try container.decodeIfPresent(String.self, forKey: .borderHex) ?? ""
        textPrimaryHex = try container.decodeIfPresent(String.self, forKey: .textPrimaryHex) ?? ""
        textSecondaryHex = try container.decodeIfPresent(String.self, forKey: .textSecondaryHex) ?? ""
        dangerHex = try container.decodeIfPresent(String.self, forKey: .dangerHex) ?? ""
        overlayHex = try container.decodeIfPresent(String.self, forKey: .overlayHex) ?? ""
    }
}

struct TypographyTokens: Codable, Equatable {
    var titleFont: String
    var bodyFont: String
    var smallFont: String
    var menuItemFont: String
    var statusFont: String

    init(
        titleFont: String = "",
        bodyFont: String = "",
        smallFont: String = "",
        menuItemFont: String = "",
        statusFont: String = ""
    ) {
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.smallFont = smallFont
        self.menuItemFont = menuItemFont
        self.statusFont = statusFont
    }

    enum CodingKeys: String, CodingKey {
        case titleFont = "title_font"
        case bodyFont = "body_font"
        case smallFont = "small_font"
        case menuItemFont = "menu_item_font"
        case statusFont = "status_font"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        titleFont = try container.decodeIfPresent(String.self, forKey: .titleFont) ?? ""
        bodyFont = try container.decodeIfPresent(String.self, forKey: .bodyFont) ?? ""
        smallFont = try container.decodeIfPresent(String.self, forKey: .smallFont) ?? ""
        menuItemFont = try container.decodeIfPresent(String.self, forKey: .menuItemFont) ?? ""
        statusFont = try container.decodeIfPresent(String.self, forKey: .statusFont) ?? ""
    }
}

struct SurfaceTokens: Codable, Equatable {
    var cornerRadius: String
    var borderWidth: String
    var shadow: String
    var padding: String
    var spacing: String
    var panelWidthPolicy: String

    init(
        cornerRadius: String = "",
        borderWidth: String = "",
        shadow: String = "",
        padding: String = "",
        spacing: String = "",
        panelWidthPolicy: String = ""
    ) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.shadow = shadow
        self.padding = padding
        self.spacing = spacing
        self.panelWidthPolicy = panelWidthPolicy
    }

    enum CodingKeys: String, CodingKey {
        case cornerRadius = "corner_radius"
        case borderWidth = "border_width"
        case shadow
        case padding
        case spacing
        case panelWidthPolicy = "panel_width_policy"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cornerRadius = try container.decodeIfPresent(String.self, forKey: .cornerRadius) ?? ""
        borderWidth = try container.decodeIfPresent(String.self, forKey: .borderWidth) ?? ""
        shadow = try container.decodeIfPresent(String.self, forKey: .shadow) ?? ""
        padding = try container.decodeIfPresent(String.self, forKey: .padding) ?? ""
        spacing = try container.decodeIfPresent(String.self, forKey: .spacing) ?? ""
        panelWidthPolicy = try container.decodeIfPresent(String.self, forKey: .panelWidthPolicy) ?? ""
    }
}

struct MotionTokens: Codable, Equatable {
    var panelPopInDuration: Double
    var hoverPulseDuration: Double
    var selectionTransitionDuration: Double
    var panelFadeDuration: Double

    init(
        panelPopInDuration: Double = 0,
        hoverPulseDuration: Double = 0,
        selectionTransitionDuration: Double = 0,
        panelFadeDuration: Double = 0
    ) {
        self.panelPopInDuration = panelPopInDuration
        self.hoverPulseDuration = hoverPulseDuration
        self.selectionTransitionDuration = selectionTransitionDuration
        self.panelFadeDuration = panelFadeDuration
    }

    enum CodingKeys: String, CodingKey {
        case panelPopInDuration = "panel_pop_in_duration"
        case hoverPulseDuration = "hover_pulse_duration"
        case selectionTransitionDuration = "selection_transition_duration"
        case panelFadeDuration = "panel_fade_duration"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        panelPopInDuration = try container.decodeIfPresent(Double.self, forKey: .panelPopInDuration) ?? 0
        hoverPulseDuration = try container.decodeIfPresent(Double.self, forKey: .hoverPulseDuration) ?? 0
        selectionTransitionDuration = try container.decodeIfPresent(Double.self, forKey: .selectionTransitionDuration) ?? 0
        panelFadeDuration = try container.decodeIfPresent(Double.self, forKey: .panelFadeDuration) ?? 0
    }
}

struct AssetTokens: Codable, Equatable {
    var pixelBorderAsset: String
    var textureAsset: String
    var cornerBadgeAsset: String
    var backgroundImageAsset: String

    init(
        pixelBorderAsset: String = "",
        textureAsset: String = "",
        cornerBadgeAsset: String = "",
        backgroundImageAsset: String = ""
    ) {
        self.pixelBorderAsset = pixelBorderAsset
        self.textureAsset = textureAsset
        self.cornerBadgeAsset = cornerBadgeAsset
        self.backgroundImageAsset = backgroundImageAsset
    }

    enum CodingKeys: String, CodingKey {
        case pixelBorderAsset = "pixel_border_asset"
        case textureAsset = "texture_asset"
        case cornerBadgeAsset = "corner_badge_asset"
        case backgroundImageAsset = "background_image_asset"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pixelBorderAsset = try container.decodeIfPresent(String.self, forKey: .pixelBorderAsset) ?? ""
        textureAsset = try container.decodeIfPresent(String.self, forKey: .textureAsset) ?? ""
        cornerBadgeAsset = try container.decodeIfPresent(String.self, forKey: .cornerBadgeAsset) ?? ""
        backgroundImageAsset = try container.decodeIfPresent(String.self, forKey: .backgroundImageAsset) ?? ""
    }
}

struct ThemeComponentTokens: Codable, Equatable {
    var panel: PanelComponentTokens
    var button: ButtonComponentTokens
    var menuPanel: MenuPanelComponentTokens
    var menuRow: MenuRowComponentTokens
    var textField: TextFieldComponentTokens

    init(
        panel: PanelComponentTokens = PanelComponentTokens(),
        button: ButtonComponentTokens = ButtonComponentTokens(),
        menuPanel: MenuPanelComponentTokens = MenuPanelComponentTokens(),
        menuRow: MenuRowComponentTokens = MenuRowComponentTokens(),
        textField: TextFieldComponentTokens = TextFieldComponentTokens()
    ) {
        self.panel = panel
        self.button = button
        self.menuPanel = menuPanel
        self.menuRow = menuRow
        self.textField = textField
    }

    enum CodingKeys: String, CodingKey {
        case panel
        case button
        case menuPanel = "menu_panel"
        case menuRow = "menu_row"
        case textField = "text_field"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        panel = try container.decodeIfPresent(PanelComponentTokens.self, forKey: .panel) ?? PanelComponentTokens()
        button = try container.decodeIfPresent(ButtonComponentTokens.self, forKey: .button) ?? ButtonComponentTokens()
        menuPanel = try container.decodeIfPresent(MenuPanelComponentTokens.self, forKey: .menuPanel) ?? MenuPanelComponentTokens()
        menuRow = try container.decodeIfPresent(MenuRowComponentTokens.self, forKey: .menuRow) ?? MenuRowComponentTokens()
        textField = try container.decodeIfPresent(TextFieldComponentTokens.self, forKey: .textField) ?? TextFieldComponentTokens()
    }
}

struct PanelComponentTokens: Codable, Equatable {
    var padding: String
    var cornerRadius: String

    init(padding: String = "", cornerRadius: String = "") {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    enum CodingKeys: String, CodingKey {
        case padding
        case cornerRadius = "corner_radius"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        padding = try container.decodeIfPresent(String.self, forKey: .padding) ?? ""
        cornerRadius = try container.decodeIfPresent(String.self, forKey: .cornerRadius) ?? ""
    }
}

struct ButtonComponentTokens: Codable, Equatable {
    var padding: String
    var cornerRadius: String

    init(padding: String = "", cornerRadius: String = "") {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    enum CodingKeys: String, CodingKey {
        case padding
        case cornerRadius = "corner_radius"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        padding = try container.decodeIfPresent(String.self, forKey: .padding) ?? ""
        cornerRadius = try container.decodeIfPresent(String.self, forKey: .cornerRadius) ?? ""
    }
}

struct MenuPanelComponentTokens: Codable, Equatable {
    var padding: String
    var rowSpacing: String

    init(padding: String = "", rowSpacing: String = "") {
        self.padding = padding
        self.rowSpacing = rowSpacing
    }

    enum CodingKeys: String, CodingKey {
        case padding
        case rowSpacing = "row_spacing"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        padding = try container.decodeIfPresent(String.self, forKey: .padding) ?? ""
        rowSpacing = try container.decodeIfPresent(String.self, forKey: .rowSpacing) ?? ""
    }
}

struct MenuRowComponentTokens: Codable, Equatable {
    var padding: String
    var hoverBackgroundHex: String

    init(padding: String = "", hoverBackgroundHex: String = "") {
        self.padding = padding
        self.hoverBackgroundHex = hoverBackgroundHex
    }

    enum CodingKeys: String, CodingKey {
        case padding
        case hoverBackgroundHex = "hover_background_hex"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        padding = try container.decodeIfPresent(String.self, forKey: .padding) ?? ""
        hoverBackgroundHex = try container.decodeIfPresent(String.self, forKey: .hoverBackgroundHex) ?? ""
    }
}

struct TextFieldComponentTokens: Codable, Equatable {
    var padding: String
    var cornerRadius: String

    init(padding: String = "", cornerRadius: String = "") {
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    enum CodingKeys: String, CodingKey {
        case padding
        case cornerRadius = "corner_radius"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        padding = try container.decodeIfPresent(String.self, forKey: .padding) ?? ""
        cornerRadius = try container.decodeIfPresent(String.self, forKey: .cornerRadius) ?? ""
    }
}
