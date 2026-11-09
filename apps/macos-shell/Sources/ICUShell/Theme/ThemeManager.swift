import Foundation

extension Notification.Name {
    static let icuThemeDidChange = Notification.Name("ICUShell.ThemeDidChange")
}

/// 当前主题。AI 换主题砍掉之后只剩像素主题，保留这一层是为了让界面统一从这里取颜色和字体。
final class ThemeManager {
    let currentTheme: ThemeDefinition

    private static var sharedStorage: ThemeManager?

    static var shared: ThemeManager {
        guard let manager = sharedStorage else {
            fatalError("ThemeManager.shared was accessed before installShared(_:)")
        }
        return manager
    }

    static func installShared(_ manager: ThemeManager) {
        sharedStorage = manager
    }

    init(theme: ThemeDefinition = PixelTheme.definition) {
        currentTheme = theme
    }
}
