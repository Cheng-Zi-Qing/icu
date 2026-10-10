import QuartzCore
import Foundation

/// 持续生命层 — 三条正弦叠加，让桌宠永远"活着"
final class LifeLayer {

    struct Amplitudes {
        var breathScale: CGFloat     // 呼吸缩放幅度
        var floatTranslate: CGFloat  // 浮动位移幅度（px）
        var swayRotate: CGFloat      // 摇摆角度幅度（度）
    }

    static func amplitudes(for stateID: String) -> Amplitudes {
        switch stateID {
        case "working": return Amplitudes(breathScale: 0.012, floatTranslate: 1.5, swayRotate: 1.5)
        case "focus":   return Amplitudes(breathScale: 0.008, floatTranslate: 0.8, swayRotate: 0.3)
        case "alert":   return Amplitudes(breathScale: 0.025, floatTranslate: 3.5, swayRotate: 1.2)
        default:        return Amplitudes(breathScale: 0.018, floatTranslate: 2.5, swayRotate: 0.8)
        }
    }

    // 三条正弦周期（互质，永不对齐）
    private let breathPeriod: CGFloat = 3.2
    private let floatPeriod:  CGFloat = 4.7
    private let swayPeriod:   CGFloat = 6.1

    private var currentAmplitudes: Amplitudes = LifeLayer.amplitudes(for: "idle")
    private var targetAmplitudes:  Amplitudes = LifeLayer.amplitudes(for: "idle")
    private var amplitudeTransitionStart: CFTimeInterval = 0
    private let amplitudeTransitionDuration: CFTimeInterval = 0.6

    func setStateID(_ stateID: String, at time: CFTimeInterval) {
        currentAmplitudes = lerpedAmplitudes(at: time)
        targetAmplitudes  = LifeLayer.amplitudes(for: stateID)
        amplitudeTransitionStart = time
    }

    var currentTranslateY: CGFloat = 0

    func evaluate(at time: CFTimeInterval) -> LayerTransform {
        let amp = lerpedAmplitudes(at: time)
        let breathScale  = sin(CGFloat(time) * 2 * .pi / breathPeriod) * amp.breathScale
        let floatY       = sin(CGFloat(time) * 2 * .pi / floatPeriod)  * amp.floatTranslate
        let swayDegrees  = sin(CGFloat(time) * 2 * .pi / swayPeriod)   * amp.swayRotate
        currentTranslateY = floatY
        return LayerTransform(
            scaleX: 1 + breathScale,
            scaleY: 1 + breathScale,
            rotateZ: swayDegrees,
            translateY: floatY
        )
    }

    private func lerpedAmplitudes(at time: CFTimeInterval) -> Amplitudes {
        let elapsed = time - amplitudeTransitionStart
        let rawT = amplitudeTransitionDuration > 0 ? CGFloat(elapsed / amplitudeTransitionDuration) : 1
        let t = AnimationCurve.easeInOut.evaluate(at: min(rawT, 1))
        return Amplitudes(
            breathScale:    currentAmplitudes.breathScale  + (targetAmplitudes.breathScale  - currentAmplitudes.breathScale)  * t,
            floatTranslate: currentAmplitudes.floatTranslate + (targetAmplitudes.floatTranslate - currentAmplitudes.floatTranslate) * t,
            swayRotate:     currentAmplitudes.swayRotate   + (targetAmplitudes.swayRotate   - currentAmplitudes.swayRotate)   * t
        )
    }
}
