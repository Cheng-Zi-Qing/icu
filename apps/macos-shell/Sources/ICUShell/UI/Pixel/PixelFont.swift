import AppKit
import CoreText

/// 像素字（Fusion Pixel 12px，OFL 授权，随 app 放在 assets/fonts）。
/// 只有 12pt 的整数倍才是清晰的点阵；没注册成功时退回系统等宽字。
enum PixelFont {
    static let fileName = "fusion-pixel-12px-proportional-zh_hans.otf"
    static let pointSize: CGFloat = 12

    private static var registeredName: String?

    /// 在 app 启动时调用一次；找不到字体文件不影响启动
    static func register(assetsDirectory: URL?) {
        guard registeredName == nil, let assetsDirectory else { return }
        let url = assetsDirectory.appendingPathComponent("fonts", isDirectory: true).appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            NSLog("[PixelFont] font file missing at \(url.path), using system font")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            let reason = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            // 重复注册也会报错，但字体照样可用，所以继续往下取名字
            NSLog("[PixelFont] register returned an error: \(reason)")
        }
        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
            let name = descriptors.first.flatMap({ CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String })
        else {
            NSLog("[PixelFont] could not read font name from \(url.path)")
            return
        }
        registeredName = name
    }

    static var isAvailable: Bool {
        registeredName.flatMap { NSFont(name: $0, size: pointSize) } != nil
    }

    static func font() -> NSFont {
        registeredName.flatMap { NSFont(name: $0, size: pointSize) }
            ?? .monospacedSystemFont(ofSize: pointSize, weight: .medium)
    }
}
