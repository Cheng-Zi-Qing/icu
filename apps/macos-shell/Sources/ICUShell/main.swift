import AppKit

// 不显示 Dock 图标，作为桌面常驻应用运行
NSApplication.shared.setActivationPolicy(.accessory)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
