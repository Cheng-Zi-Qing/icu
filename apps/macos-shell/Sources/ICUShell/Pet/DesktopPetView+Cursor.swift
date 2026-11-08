import AppKit

/// 桌宠上的手型光标：头上摸摸、身上张手、按住 / 拖着时握拳，透明区域是普通箭头
extension DesktopPetView {
    /// - Parameter point: 视图坐标；nil 表示鼠标离开了桌宠窗口
    func updateCursor(at point: NSPoint?) {
        let kind = PetCursorKind.kind(
            isGrabbing: isPressingPet || isDraggingPet,
            overBody: point.map(isOpaquePetPixel(at:)) ?? false,
            overHead: point.map(isOverHead) ?? false
        )
        currentCursorKind = kind
        // 每次都重新设：前台 App 可能把光标改回去
        (kind.map(cursorSet.cursor(for:)) ?? NSCursor.arrow).set()
    }
}
