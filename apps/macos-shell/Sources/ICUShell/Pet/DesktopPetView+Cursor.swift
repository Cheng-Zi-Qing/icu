import AppKit

/// 桌宠上的手型光标：头上摸摸、身上张手、按住 / 拖着时握拳，透明区域不碰光标（下面的 App 说了算）
extension DesktopPetView {
    /// - Parameter point: 视图坐标；nil 表示鼠标离开了桌宠窗口
    func updateCursor(at eventPoint: NSPoint?) {
        let point = eventPoint.flatMap(pointerIfReallyHere)
        let kind = PetCursorKind.kind(
            isGrabbing: isPressingPet || isDraggingPet,
            overBody: point.map(isOpaquePetPixel(at:)) ?? false,
            overHead: point.map(isOverHead) ?? false
        )
        let update = PetCursorKind.update(from: currentCursorKind, to: kind)
        currentCursorKind = kind
        switch update {
        case .show(let shown):
            // 桌宠平时不在前台，先放开「后台改光标」，手型才看得到
            cursorGate.setOpen(true)
            cursorSet.cursor(for: shown).set()
        case .restoreArrow:
            NSCursor.arrow.set()
            cursorGate.setOpen(false)
        case .leaveAlone:
            cursorGate.setOpen(false)
        }
    }

    /// 状态条刷新、窗口变大小时 AppKit 会补发鼠标事件，里面的位置可能是过期的。
    /// 以鼠标真正的位置为准：不在桌宠窗口里就当鼠标不在（不然会在别的 App 上设手型，抢光标变白方块）
    private func pointerIfReallyHere(_ eventPoint: NSPoint) -> NSPoint? {
        guard let window else { return eventPoint }
        let actual = convert(window.convertPoint(fromScreen: pointerLocation()), from: nil)
        return bounds.contains(actual) ? actual : nil
    }
}
