import AppKit

struct PetMotionEnhancer {
    struct Profile: Equatable {
        var stateID: String
        var scale: CGFloat
        var verticalOffset: CGFloat
        var rotationDegrees: CGFloat
        var shadowOpacity: Float
        var shadowRadius: CGFloat
        var variantRotationCooldownTicks: Int
    }

    static func profile(for stateID: String) -> Profile {
        switch stateID {
        case "working":
            return Profile(
                stateID: "working",
                scale: 1.02,
                verticalOffset: 1,
                rotationDegrees: -1.5,
                shadowOpacity: 0.18,
                shadowRadius: 5,
                variantRotationCooldownTicks: 5
            )
        case "alert":
            return Profile(
                stateID: "alert",
                scale: 1.06,
                verticalOffset: 2,
                rotationDegrees: 2.5,
                shadowOpacity: 0.26,
                shadowRadius: 7,
                variantRotationCooldownTicks: 3
            )
        default:
            return Profile(
                stateID: "idle",
                scale: 1.0,
                verticalOffset: 0,
                rotationDegrees: -0.5,
                shadowOpacity: 0.12,
                shadowRadius: 4,
                variantRotationCooldownTicks: 8
            )
        }
    }

    static func apply(_ profile: Profile, to imageView: NSImageView?) {
        guard let imageView else {
            return
        }

        imageView.wantsLayer = true
        guard let layer = imageView.layer else {
            return
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, 0, profile.verticalOffset, 0)
        transform = CATransform3DRotate(transform, profile.rotationDegrees * .pi / 180, 0, 0, 1)
        transform = CATransform3DScale(transform, profile.scale, profile.scale, 1)
        layer.transform = transform
        layer.shadowColor = NSColor.black.withAlphaComponent(0.45).cgColor
        layer.shadowOpacity = profile.shadowOpacity
        layer.shadowRadius = profile.shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: -max(profile.verticalOffset, 1))

        CATransaction.commit()
    }
}
