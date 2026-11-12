import AppKit

/// 桌宠窗口的宽度跟着画面走：趴着、追球这些场景的帧比平时宽（像素管线里 38–50 格，平时 32 格），
/// 窗口放宽到放得下，水豚还是一样大；回到平时的画面再收回来。左右对称地放宽 / 收窄，水豚在屏幕上不挪地方。
enum PetWindowWidth {
    /// 画面要多宽：至少是平时的画布宽
    static func width(for image: NSImage?, normal: CGFloat) -> CGFloat {
        max(normal, (image?.size.width ?? 0).rounded())
    }

    /// 窗口改成 `width` 宽，中心不动；已经是这么宽就原样返回
    static func frame(_ frame: CGRect, fittingWidth width: CGFloat) -> CGRect {
        guard abs(frame.width - width) >= 0.5 else { return frame }
        return frame.insetBy(dx: (frame.width - width) / 2, dy: 0)
    }
}
