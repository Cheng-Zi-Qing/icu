import Foundation

enum PixelTheme {
    static let id = "pixel_default"

    static let pack = ThemePack(
        meta: ThemePack.Meta(
            id: id,
            name: "Pixel Default",
            version: 1,
            sourcePrompt: "Default built-in pixel theme."
        ),
        tokens: ThemeTokens(
            colors: ColorTokens(
                windowBackgroundHex: "#141A14",
                cardBackgroundHex: "#1F261D",
                inputBackgroundHex: "#2D362A",
                menuBackgroundHex: "#1B2419",
                accentHex: "#94DD63",
                borderHex: "#4A6142",
                textPrimaryHex: "#E5F2DE",
                textSecondaryHex: "#AFBEA8",
                dangerHex: "#D65F5F",
                overlayHex: "#00000099"
            ),
            typography: TypographyTokens(
                titleFont: "Menlo-Bold 18",
                bodyFont: "Menlo 12",
                smallFont: "Menlo 11",
                menuItemFont: "Menlo 12",
                statusFont: "Menlo 11"
            ),
            surface: SurfaceTokens(
                cornerRadius: "10",
                borderWidth: "1",
                shadow: "none",
                padding: "12",
                spacing: "8",
                panelWidthPolicy: "content"
            ),
            motion: MotionTokens(
                panelPopInDuration: 0.18,
                hoverPulseDuration: 0.1,
                selectionTransitionDuration: 0.12,
                panelFadeDuration: 0.16
            ),
            assets: AssetTokens(
                pixelBorderAsset: "",
                textureAsset: "",
                cornerBadgeAsset: "",
                backgroundImageAsset: ""
            )
        ),
        components: ThemeComponentTokens(
            panel: PanelComponentTokens(padding: "12", cornerRadius: "12"),
            button: ButtonComponentTokens(padding: "8 12", cornerRadius: "10"),
            menuPanel: MenuPanelComponentTokens(padding: "6", rowSpacing: "2"),
            menuRow: MenuRowComponentTokens(padding: "8 10", hoverBackgroundHex: "#2B3627"),
            textField: TextFieldComponentTokens(padding: "8", cornerRadius: "10")
        )
    )

    static let definition = ThemeDefinition(pack: pack)
}
