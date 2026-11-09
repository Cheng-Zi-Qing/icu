import AppKit
import Darwin

// 单实例保护：flock 在进程被杀后由内核自动释放，不会留下永远解不开的死锁
// 拿不到锁文件路径时放行启动——加锁不该把 app 变成彻底打不开
let lockFileURL = (try? AppPaths.live())?.rootURL.appendingPathComponent("instance.lock", isDirectory: false)
var instanceLockDescriptor: Int32?
var isBlockedByRunningInstance = false

if let lockFileURL {
    try? FileManager.default.createDirectory(
        at: lockFileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let descriptor = open(lockFileURL.path, O_RDWR | O_CREAT, 0o644)
    if descriptor >= 0 {
        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
            // 描述符必须在进程生命周期内一直开着，关掉就等于放锁
            instanceLockDescriptor = descriptor
        } else {
            close(descriptor)
            isBlockedByRunningInstance = true
        }
    }
}

// 已有实例在跑：安静退出，不弹窗不刷日志，用户双击图标没反应比弹个框好
if isBlockedByRunningInstance {
    exit(0)
}

// 不显示 Dock 图标，作为桌面常驻应用运行
NSApplication.shared.setActivationPolicy(.accessory)

// 顶层代码在主线程上跑，告诉编译器这一点，才能创建主线程隔离的 AppDelegate
let delegate = MainActor.assumeIsolated { AppDelegate() }
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
