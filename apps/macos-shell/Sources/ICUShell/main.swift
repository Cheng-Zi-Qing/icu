import AppKit

// 不显示 Dock 图标，作为桌面常驻应用运行
NSApplication.shared.setActivationPolicy(.accessory)

// 顶层代码在主线程上跑，告诉编译器这一点，才能创建主线程隔离的 AppDelegate
let delegate = MainActor.assumeIsolated { AppDelegate() }
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
