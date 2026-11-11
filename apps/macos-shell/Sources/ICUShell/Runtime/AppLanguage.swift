import Foundation

/// 界面语言：`settings.json` 顶层的 `language`。缺失或写错都当中文（老用户默认）
enum AppLanguage: String, CaseIterable, Equatable {
    case chinese = "zh"
    case english = "en"

    static func stored(_ rawValue: String?) -> AppLanguage {
        rawValue.flatMap(AppLanguage.init(rawValue:)) ?? .chinese
    }

    /// 设置里显示的名字：各语言用各自的语言写
    var title: String {
        TextCatalog.shared.text("settings.language_\(rawValue)")
    }
}
