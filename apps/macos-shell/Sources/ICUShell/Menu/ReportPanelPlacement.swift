import Foundation

/// 今日报告面板放哪：挨着桌宠，不挡桌宠，也不出屏幕
enum ReportPanelPlacement {
    static let gap: CGFloat = 12

    /// 先放桌宠朝屏幕中间的那一侧（和桌宠上下居中），放不下换另一侧，再不行放上面、下面；
    /// 都放不下（屏幕太小）就贴着桌宠放在屏幕里
    static func frame(size: CGSize, beside pet: CGRect, in visible: CGRect) -> CGRect {
        let towardCenterIsRight = pet.midX < visible.midX
        let sideY = clamp(pet.midY - size.height / 2, visible.minY, visible.maxY - size.height)
        let sideX = { (right: Bool) in right ? pet.maxX + gap : pet.minX - gap - size.width }
        let aboveBelowX = clamp(pet.midX - size.width / 2, visible.minX, visible.maxX - size.width)

        let candidates = [
            CGRect(x: sideX(towardCenterIsRight), y: sideY, width: size.width, height: size.height),
            CGRect(x: sideX(!towardCenterIsRight), y: sideY, width: size.width, height: size.height),
            CGRect(x: aboveBelowX, y: pet.maxY + gap, width: size.width, height: size.height),
            CGRect(x: aboveBelowX, y: pet.minY - gap - size.height, width: size.width, height: size.height),
        ]
        if let fitting = candidates.first(where: { visible.contains($0) }) {
            return fitting
        }
        let fallback = candidates[0]
        return CGRect(
            x: clamp(fallback.minX, visible.minX, visible.maxX - size.width),
            y: clamp(fallback.minY, visible.minY, visible.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    /// 菜单栏按钮下面：右边和按钮对齐往左长（按钮都在屏幕右上角），不出屏幕
    static func frame(size: CGSize, below button: CGRect, in visible: CGRect) -> CGRect {
        CGRect(
            x: clamp(button.maxX - size.width, visible.minX, visible.maxX - size.width),
            y: clamp(button.minY - 6 - size.height, visible.minY, visible.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        max(lower, min(value, max(lower, upper)))
    }
}
