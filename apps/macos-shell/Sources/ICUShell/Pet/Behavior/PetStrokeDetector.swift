import CoreGraphics
import Foundation

/// 摸头手势（参考 VPet 的「摸头」）：鼠标在头上来回蹭几下。
///
/// 每段移动都要超过 `minimumTravel`（滤掉手抖），在 `window` 秒内掉头够
/// `requiredReversals` 次（来—回—来）才算一次摸头。不可变：`feeding` 返回新状态。
struct PetStrokeDetector: Equatable {
    static let minimumTravel: CGFloat = 6
    static let requiredReversals = 2
    static let window: TimeInterval = 1.2

    /// 当前这一段走到的最远点
    private var extremeX: CGFloat?
    /// 当前这一段的方向：-1 往左，1 往右，0 还没走出最小距离
    private var direction: CGFloat = 0
    private var reversalTimes: [TimeInterval] = []

    /// 喂一个鼠标位置（视图坐标 x）；返回新状态，以及是否刚凑够一次摸头
    func feeding(x: CGFloat, at time: TimeInterval) -> (PetStrokeDetector, Bool) {
        guard let extremeX else {
            return (PetStrokeDetector(extremeX: x, direction: 0, reversalTimes: []), false)
        }

        let delta = x - extremeX
        let recent = reversalTimes.filter { time - $0 <= Self.window }

        if direction == 0 {
            guard abs(delta) >= Self.minimumTravel else { return (self, false) }
            return (PetStrokeDetector(extremeX: x, direction: delta > 0 ? 1 : -1, reversalTimes: recent), false)
        }
        if delta * direction >= 0 {
            // 同方向继续走：只把最远点往前推
            return (PetStrokeDetector(extremeX: x, direction: direction, reversalTimes: recent), false)
        }
        guard abs(delta) >= Self.minimumTravel else { return (self, false) }

        let reversals = recent + [time]
        if reversals.count >= Self.requiredReversals {
            return (PetStrokeDetector(extremeX: x, direction: -direction, reversalTimes: []), true)
        }
        return (PetStrokeDetector(extremeX: x, direction: -direction, reversalTimes: reversals), false)
    }
}
