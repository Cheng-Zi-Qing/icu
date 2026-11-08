import AppKit
import Darwin

/// 「后台也能改光标」的开关。
///
/// 桌宠是常驻菜单栏的辅助 App，平时前台是别的 App；macOS 默认只认前台 App 设的光标，
/// 鼠标移到桌宠上还是普通箭头。窗口服务器有个连接属性 `SetsCursorInBackground`
/// 可以放开这个限制（悬浮工具类 App 常用），但它是私有接口：运行时查找，找不到就打不开，
/// 桌宠照常工作，只是光标可能不变。
///
/// 只在鼠标真在豚鼠身上时打开：一直开着的话，鼠标停在别的 App（比如 Otty）上时，
/// 系统隔一阵会把 ICU 上次设的手型又套回来，图像没传过去，就成了一闪一闪的白方块。
final class BackgroundCursorGate {
    private let apply: (Bool) -> Bool
    private(set) var isOpen = false

    /// - Parameter apply: 真正去改窗口服务器的属性；成功返回 true
    init(apply: @escaping (Bool) -> Bool) {
        self.apply = apply
    }

    /// 只在状态变化时才碰窗口服务器；打不开就当关着
    @discardableResult
    func setOpen(_ open: Bool) -> Bool {
        guard open != isOpen else { return true }
        guard apply(open) else {
            isOpen = false
            return false
        }
        isOpen = open
        return true
    }

    /// 所有桌宠共用一个（属性是挂在整个 App 的窗口服务器连接上的）。
    /// 排查光标问题时可以用 `ICU_BACKGROUND_CURSOR=0` 关掉（桌宠不在前台时就不换手型）
    static let shared = live()

    static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> BackgroundCursorGate {
        guard environment["ICU_BACKGROUND_CURSOR"] != "0" else {
            NSLog("[BackgroundCursor] disabled by ICU_BACKGROUND_CURSOR=0")
            return BackgroundCursorGate { _ in false }
        }
        guard let setter = WindowServerCursorProperty.resolve() else {
            NSLog("[BackgroundCursor] Window server cursor property unavailable; pet cursors only show while ICU is in front")
            return BackgroundCursorGate { _ in false }
        }
        return BackgroundCursorGate(apply: setter)
    }
}

/// 运行时找 `CGSSetConnectionProperty`，返回一个设置 `SetsCursorInBackground` 的函数
private enum WindowServerCursorProperty {
    private typealias DefaultConnection = @convention(c) () -> Int32
    private typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    static func resolve() -> ((Bool) -> Bool)? {
        guard
            let handle = dlopen(nil, RTLD_NOW),
            let connectionSymbol = dlsym(handle, "_CGSDefaultConnection"),
            let setPropertySymbol = dlsym(handle, "CGSSetConnectionProperty")
        else { return nil }
        let connection = unsafeBitCast(connectionSymbol, to: DefaultConnection.self)
        let setProperty = unsafeBitCast(setPropertySymbol, to: SetConnectionProperty.self)
        return { open in
            let id = connection()
            let result = setProperty(id, id, "SetsCursorInBackground" as CFString, open ? kCFBooleanTrue : kCFBooleanFalse)
            if result != 0 {
                NSLog("[BackgroundCursor] SetsCursorInBackground=\(open) failed with error \(result)")
            }
            return result == 0
        }
    }
}
