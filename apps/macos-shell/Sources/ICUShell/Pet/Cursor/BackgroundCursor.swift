import AppKit
import Darwin

/// 允许不在前台的 App 改光标。
///
/// 桌宠是常驻菜单栏的辅助 App，平时前台是别的 App；macOS 默认只认前台 App 设的光标，
/// 鼠标移到桌宠上还是普通箭头。窗口服务器有个连接属性 `SetsCursorInBackground`
/// 可以放开这个限制（悬浮工具类 App 常用），但它是私有接口：这里运行时查找，
/// 找不到就返回 false，桌宠照常工作，只是光标可能不变。
enum BackgroundCursor {
    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static var isEnabled = false

    /// 打开「后台也能改光标」；可以重复调用
    @discardableResult
    static func enable() -> Bool {
        guard !isEnabled else { return true }
        guard
            let handle = dlopen(nil, RTLD_NOW),
            let connectionSymbol = dlsym(handle, "_CGSDefaultConnection"),
            let setPropertySymbol = dlsym(handle, "CGSSetConnectionProperty")
        else {
            print("[BackgroundCursor] Window server cursor property unavailable; pet cursors only show while ICU is in front")
            return false
        }
        let connection = unsafeBitCast(connectionSymbol, to: DefaultConnection.self)()
        let setProperty = unsafeBitCast(setPropertySymbol, to: SetConnectionProperty.self)
        let result = setProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        guard result == 0 else {
            print("[BackgroundCursor] SetsCursorInBackground failed with error \(result)")
            return false
        }
        isEnabled = true
        return true
    }
}
