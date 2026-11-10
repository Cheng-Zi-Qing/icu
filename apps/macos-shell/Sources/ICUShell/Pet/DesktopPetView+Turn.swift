import AppKit

/// 转头看鼠标时的转身：侧面 → 正脸对着你停一下 → 另一侧。瞬间镜像太突兀，像突然翻了个面。
/// 没有正面帧的宠物直接镜像。贴边、追球、放下时的转向不走这里（见 setFacingRight）
extension DesktopPetView {
    /// 正面停多久
    static let turnFrontDuration: TimeInterval = 0.2

    var isTurning: Bool { turnTarget != nil }

    func turn(toFacingRight facingRight: Bool) {
        guard !isTurning, facingRight != isFacingRight else { return }
        guard let front = turnSprites?.image(named: "front.png"), !isShowingDragPose, !isPeeking else {
            setFacingRight(facingRight)
            return
        }
        turnTarget = facingRight
        turnImage = front
        present(restingImage)
        let timer = Timer(timeInterval: Self.turnFrontDuration, repeats: false) { [weak self] _ in
            self?.finishTurn()
        }
        RunLoop.main.add(timer, forMode: .common)
        turnTimer = timer
    }

    func finishTurnForTesting() {
        finishTurn()
    }

    /// 停掉正在进行的转身（不换朝向）；返回刚才是不是在转
    @discardableResult
    func cancelTurn() -> Bool {
        let wasTurning = isTurning
        turnTimer?.invalidate()
        turnTimer = nil
        turnTarget = nil
        turnImage = nil
        return wasTurning
    }

    /// 正面帧撤下后换回该显示的画面（中途被拎起 / 探头时它们自己的画面已经在上面了）
    func presentAfterTurn() {
        present(isShowingDragPose || isPeeking ? presentedSource : restingImage)
    }

    private func finishTurn() {
        guard let target = turnTarget else { return }
        cancelTurn()
        // 转到一半被拎起来、探头了：那边自己管朝向，这一下就不转了
        guard !isShowingDragPose, !isPeeking else {
            presentAfterTurn()
            return
        }
        isFacingRight = target
        presentAfterTurn()
        layoutStatusChip()
    }
}
