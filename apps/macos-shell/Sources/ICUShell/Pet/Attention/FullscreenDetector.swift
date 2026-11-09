import CoreGraphics
import Foundation

/// 窗口列表里的一个窗口（只用到窗口服务器不需要录屏权限就给的字段）
struct OnScreenWindow: Equatable {
    let ownerPID: pid_t
    /// 0 = 普通窗口；菜单栏、Dock、浮窗都在更高的层
    let layer: Int
    /// 全局坐标，左上角为原点（和 CGDisplayBounds 同一套）
    let bounds: CGRect
    /// 0 = 透明（铺满屏幕的隐形浮层不算全屏）
    var alpha: CGFloat = 1
}

/// 前台 App 是不是在全屏（看视频、演示、全屏游戏）：它有一个普通层的窗口正好铺满某块屏幕。
/// 最大化的窗口会让出菜单栏和 Dock，不算
enum FullscreenDetector {
    /// 窗口和屏幕差这么点也算铺满（缩放后的半点误差）
    private static let tolerance: CGFloat = 1

    static func isFullscreen(frontmostPID: pid_t?, windows: [OnScreenWindow], screens: [CGRect]) -> Bool {
        guard let frontmostPID else { return false }
        return windows.contains { window in
            window.ownerPID == frontmostPID && window.layer == 0 && window.alpha > 0
                && screens.contains { covers(window.bounds, $0) }
        }
    }

    /// 屏幕上的窗口（从前往后），读不到时为空
    static func liveWindows() -> [OnScreenWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return info.compactMap { entry in
            guard
                let pid = entry[kCGWindowOwnerPID as String] as? Int,
                let layer = entry[kCGWindowLayer as String] as? Int,
                let boundsDictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else { return nil }
            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            return OnScreenWindow(ownerPID: pid_t(pid), layer: layer, bounds: bounds, alpha: CGFloat(alpha))
        }
    }

    /// 每块屏幕的范围（左上角为原点，和窗口列表同一套坐标）
    static func liveScreens() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }

    private static func covers(_ window: CGRect, _ screen: CGRect) -> Bool {
        abs(window.minX - screen.minX) <= tolerance && abs(window.minY - screen.minY) <= tolerance
            && abs(window.width - screen.width) <= tolerance && abs(window.height - screen.height) <= tolerance
    }
}
