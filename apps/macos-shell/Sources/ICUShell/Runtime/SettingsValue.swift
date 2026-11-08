import Foundation

/// settings.json 里的数值读取：不是数字、是布尔值、超出范围都当作没填
enum SettingsValue {
    static func number(_ raw: Any?, in range: ClosedRange<Double>) -> Double? {
        guard let value = (raw as? NSNumber)?.doubleValue, !(raw is Bool) else { return nil }
        return range.contains(value) ? value : nil
    }
}
