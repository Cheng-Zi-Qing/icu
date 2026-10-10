import AppKit
import QuartzCore

/// 单层动画输出的 transform 描述
struct LayerTransform {
    var scaleX: CGFloat = 1.0
    var scaleY: CGFloat = 1.0
    var rotateZ: CGFloat = 0.0       // 度数
    var rotateX: CGFloat = 0.0       // 度数，用于视差
    var rotateY: CGFloat = 0.0       // 度数，用于视差
    var translateY: CGFloat = 0.0    // 像素
    var perspective: CGFloat = 0.0   // transform.m34，0 表示无透视

    /// 零变换（单位矩阵）
    static let identity = LayerTransform()

    /// 叠加两个 LayerTransform（加法合成）
    static func + (lhs: LayerTransform, rhs: LayerTransform) -> LayerTransform {
        LayerTransform(
            scaleX: lhs.scaleX * rhs.scaleX,
            scaleY: lhs.scaleY * rhs.scaleY,
            rotateZ: lhs.rotateZ + rhs.rotateZ,
            rotateX: lhs.rotateX + rhs.rotateX,
            rotateY: lhs.rotateY + rhs.rotateY,
            translateY: lhs.translateY + rhs.translateY,
            perspective: max(lhs.perspective, rhs.perspective)  // 取较大值
        )
    }

    /// 线性插值
    func lerp(to target: LayerTransform, t: CGFloat) -> LayerTransform {
        let clampedT = max(0, min(1, t))
        return LayerTransform(
            scaleX: scaleX + (target.scaleX - scaleX) * clampedT,
            scaleY: scaleY + (target.scaleY - scaleY) * clampedT,
            rotateZ: rotateZ + (target.rotateZ - rotateZ) * clampedT,
            rotateX: rotateX + (target.rotateX - rotateX) * clampedT,
            rotateY: rotateY + (target.rotateY - rotateY) * clampedT,
            translateY: translateY + (target.translateY - translateY) * clampedT,
            perspective: perspective + (target.perspective - perspective) * clampedT
        )
    }

    /// 转为 CATransform3D
    var caTransform: CATransform3D {
        var transform = CATransform3DIdentity

        // 透视
        if perspective != 0 {
            transform.m34 = perspective
        }

        // 平移
        transform = CATransform3DTranslate(transform, 0, translateY, 0)

        // 旋转（先 X, 再 Y, 最后 Z）
        if rotateX != 0 {
            transform = CATransform3DRotate(transform, rotateX * .pi / 180, 1, 0, 0)
        }
        if rotateY != 0 {
            transform = CATransform3DRotate(transform, rotateY * .pi / 180, 0, 1, 0)
        }
        if rotateZ != 0 {
            transform = CATransform3DRotate(transform, rotateZ * .pi / 180, 0, 0, 1)
        }

        // 缩放
        transform = CATransform3DScale(transform, scaleX, scaleY, 1)

        return transform
    }
}
