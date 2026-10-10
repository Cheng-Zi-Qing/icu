import Foundation

/// 动画缓动曲线
enum AnimationCurve {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring(stiffness: CGFloat, damping: CGFloat)

    /// 给定进度 t (0~1)，返回插值后的值 (0~1)
    func evaluate(at t: CGFloat) -> CGFloat {
        let t = max(0, min(1, t))
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t * t
        case .easeOut:
            let u = 1 - t
            return 1 - u * u * u
        case .easeInOut:
            return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        case let .spring(stiffness, damping):
            return SpringEvaluator.evaluate(t: t, stiffness: stiffness, damping: damping)
        }
    }
}

// MARK: - Spring

private enum SpringEvaluator {
    static func evaluate(t: CGFloat, stiffness: CGFloat, damping: CGFloat) -> CGFloat {
        let omega = sqrt(stiffness)
        let zeta = damping / (2 * omega)
        if zeta >= 1 {
            // overdamped
            return 1 - exp(-omega * t) * (1 + omega * t)
        }
        let omegaD = omega * sqrt(1 - zeta * zeta)
        return 1 - exp(-zeta * omega * t) * (cos(omegaD * t) + (zeta / sqrt(1 - zeta * zeta)) * sin(omegaD * t))
    }
}
