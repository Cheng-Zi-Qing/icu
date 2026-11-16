import CoreGraphics
import Foundation

/// 拎起来那只在原像素格上怎么变形：只按整格复制、挑选，不在格子之间插值。
///
/// - 拉长：脖子以下按整行复制变长，第一行（脖子）和最后一行（脚底描边）各只出现一次
/// - 收细：从脖子往下一行比一行收，脖子那行和脑袋一样宽，轮廓接得上；每行两端的描边格保留
/// - 甩动：RotSprite —— 先用 Scale2x 平滑放大 8 倍，转完再按格子中心取色，描边转过去还是连着的一格
enum PixelSpriteHanging {
    /// RotSprite 的平滑放大倍数（Scale2x 做三次）
    static let rotationOversample = 8

    /// 身体拉长后有几行：按整行取整，同一个行数画出来的样子完全一样
    static func stretchedBodyRows(bodyRows: Int, stretch: CGFloat) -> Int {
        guard bodyRows > 0 else { return 0 }
        return max(1, bodyRows + Int((CGFloat(bodyRows) * (stretch - 1)).rounded()))
    }

    /// 脑袋原样，身体拉到 `stretchedBodyRows` 行；比脖子宽出来的部分（鼓出去的背和肚子）横向压成 1 / 拉长量^slimming。
    ///
    /// 不是整行复制：先把原图每行左右边缘的台阶抹成一条顺的曲线（相邻三行取平均），
    /// 沿这条曲线拉长再取整，背和肚子的弧线跟着变长，不会被拉成竖直线；取整后单独跳出去一行的毛刺抹平。
    /// 收细只压鼓出去的那一截、不整体往中线缩：弧线形状不变只是扁一点，脖子处天然和脑袋一样宽，
    /// 本来就比脖子窄的地方（脚）也不会被撑宽。边缘移动后露在外面的毛色，补回原图那一处的描边色。
    static func hanging(
        _ sprite: PixelSpriteGrid,
        headRows: Int,
        stretchedBodyRows: Int,
        slimming: CGFloat
    ) -> PixelSpriteGrid {
        let headRows = min(max(headRows, 1), sprite.height)
        let bodyRows = sprite.height - headRows
        guard bodyRows > 0, stretchedBodyRows > 0 else { return sprite }
        let stretch = CGFloat(stretchedBodyRows) / CGFloat(bodyRows)
        let bulge = Bulge(
            neck: sprite.opaqueSpan(row: headRows - 1).map { (CGFloat($0.lowerBound), CGFloat($0.upperBound + 1)) }
                ?? (CGFloat(sprite.width) / 2, CGFloat(sprite.width) / 2),
            scale: 1 / pow(max(stretch, 1), slimming)
        )
        let curve = smoothedEdges(sprite, firstRow: headRows)

        /// 输出的第 row 行身体对应原图身体的哪个位置（连续的行号，按格子中心对齐）
        func sourceRow(_ row: Int) -> CGFloat {
            min(max((CGFloat(row) + 0.5) / stretch - 0.5, 0), CGFloat(bodyRows - 1))
        }

        let rawSpans = (0..<stretchedBodyRows).map { row -> (left: Int, right: Int)? in
            guard let edge = interpolated(curve, at: sourceRow(row)) else { return nil }
            let left = Int(bulge.slimmed(edge.left).rounded())
            return (left, max(left, Int(bulge.slimmed(edge.right).rounded()) - 1))
        }
        let neck = sprite.opaqueSpan(row: headRows - 1).map { (left: $0.lowerBound, right: $0.upperBound) }
        let spans = despiked(rawSpans, after: neck)

        let head = Array(sprite.cells[0..<(headRows * sprite.width)])
        let body = (0..<stretchedBodyRows).flatMap { row -> [UInt32] in
            let nearest = headRows + Int(sourceRow(row).rounded())
            guard let target = spans[row], let source = sprite.opaqueSpan(row: nearest) else {
                return Array(repeating: PixelSpriteGrid.clear, count: sprite.width)
            }
            return (0..<sprite.width).map { x in
                guard x >= target.left, x <= target.right else { return PixelSpriteGrid.clear }
                let column = source.lowerBound + endpointIndex(x - target.left, from: target.right - target.left + 1, to: source.count)
                return sprite[column, nearest]
            }
        }
        let shaped = PixelSpriteGrid(width: sprite.width, height: headRows + stretchedBodyRows, cells: head + body)
        return repairingSilhouette(shaped, from: sprite) { x, y in
            guard y >= headRows else { return CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5) }
            return CGPoint(x: bulge.unslimmed(CGFloat(x) + 0.5), y: CGFloat(headRows) + sourceRow(y - headRows) + 0.5)
        }
    }

    /// 比脖子宽出来的那一截按 scale 压扁；脖子范围以内原样
    private struct Bulge {
        let neck: (left: CGFloat, right: CGFloat)
        let scale: CGFloat

        func slimmed(_ x: CGFloat) -> CGFloat {
            if x > neck.right { return neck.right + (x - neck.right) * scale }
            if x < neck.left { return neck.left - (neck.left - x) * scale }
            return x
        }

        func unslimmed(_ x: CGFloat) -> CGFloat {
            if x > neck.right { return neck.right + (x - neck.right) / scale }
            if x < neck.left { return neck.left - (neck.left - x) / scale }
            return x
        }
    }

    /// 从 firstRow 往下每行的左右边缘，和上下相邻行取平均：像素台阶背后那条顺的曲线。
    /// 左边缘是第一格的左沿，右边缘是最后一格的右沿；第一行会和它上面一行（脑袋）一起平均，脖子接得上
    private static func smoothedEdges(_ sprite: PixelSpriteGrid, firstRow: Int) -> [(left: CGFloat, right: CGFloat)?] {
        let spans = (0..<sprite.height).map { sprite.opaqueSpan(row: $0) }
        return (firstRow..<sprite.height).map { row in
            guard spans[row] != nil else { return nil }
            let neighbors = (max(row - 1, 0)...min(row + 1, sprite.height - 1)).compactMap { spans[$0] }
            let count = CGFloat(neighbors.count)
            return (
                neighbors.map { CGFloat($0.lowerBound) }.reduce(0, +) / count,
                neighbors.map { CGFloat($0.upperBound + 1) }.reduce(0, +) / count
            )
        }
    }

    /// 在相邻两行之间按比例插出左右边缘
    private static func interpolated(
        _ curve: [(left: CGFloat, right: CGFloat)?], at position: CGFloat
    ) -> (left: CGFloat, right: CGFloat)? {
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, curve.count - 1)
        let fraction = position - CGFloat(lower)
        switch (curve[lower], curve[upper]) {
        case let (a?, b?):
            return (a.left + (b.left - a.left) * fraction, a.right + (b.right - a.right) * fraction)
        case let (a?, nil), let (nil, a?):
            return a
        case (nil, nil):
            return nil
        }
    }

    /// 取整后单独一行跳出去又跳回来（23, 22, 23）的毛刺抹平，像素画的边缘只朝一个方向走台阶
    private static func despiked(
        _ spans: [(left: Int, right: Int)?], after previous: (left: Int, right: Int)?
    ) -> [(left: Int, right: Int)?] {
        let padded = [previous] + spans
        return spans.indices.map { index in
            let row = index + 1
            guard let current = padded[row] else { return nil }
            guard row + 1 < padded.count, let above = padded[row - 1], let below = padded[row + 1] else { return current }
            let left = above.left == below.left ? above.left : current.left
            let right = above.right == below.right ? above.right : current.right
            return (left, max(left, right))
        }
    }

    /// 把 0..<from 的下标按比例对到 0..<to，两头的端点一一对上
    static func endpointIndex(_ index: Int, from: Int, to: Int) -> Int {
        guard from > 1, to > 1 else { return 0 }
        return Int((Double(index) * Double(to - 1) / Double(from - 1)).rounded())
    }

    // MARK: - 甩动（RotSprite）

    /// Scale2x：一格变 2×2，斜边上的阶梯补齐成更顺的斜线，不引入新颜色。
    /// 拎着甩的时候每帧都可能要算，直接在缓冲区里走（debug 构建下闭包版本要慢十倍）
    static func scale2x(_ grid: PixelSpriteGrid) -> PixelSpriteGrid {
        let width = grid.width, height = grid.height
        let outWidth = width * 2
        var cells = [UInt32](repeating: PixelSpriteGrid.clear, count: width * height * 4)
        grid.cells.withUnsafeBufferPointer { source in
            cells.withUnsafeMutableBufferPointer { out in
                for y in 0..<height {
                    for x in 0..<width {
                        let index = y * width + x
                        let center = source[index]
                        let up = y > 0 ? source[index - width] : PixelSpriteGrid.clear
                        let down = y < height - 1 ? source[index + width] : PixelSpriteGrid.clear
                        let left = x > 0 ? source[index - 1] : PixelSpriteGrid.clear
                        let right = x < width - 1 ? source[index + 1] : PixelSpriteGrid.clear
                        let topLeft = 2 * y * outWidth + 2 * x
                        let bottomLeft = topLeft + outWidth
                        // 每个子格只看它那个角挨着的两条边
                        out[topLeft] = left == up && left != down && up != right ? up : center
                        out[topLeft + 1] = up == right && up != left && right != down ? right : center
                        out[bottomLeft] = down == left && down != right && left != up ? left : center
                        out[bottomLeft + 1] = right == down && right != up && down != left ? down : center
                    }
                }
            }
        }
        return PixelSpriteGrid(width: outWidth, height: height * 2, cells: cells)
    }

    /// RotSprite 用的 8 倍平滑图
    static func oversampled(_ grid: PixelSpriteGrid) -> PixelSpriteGrid {
        scale2x(scale2x(scale2x(grid)))
    }

    /// 把 sprite 绕 pivot 转 degrees 度后，左上角放到画布的 origin 格，画进 canvasWidth × canvasHeight 的空画布。
    /// - degrees: 逆时针为正（和 Core Animation 一致：正角度脚往右荡）
    /// - pivot: 以 sprite 左上角为原点、往下为正的格子坐标（可以落在格线上）
    /// - oversampled: `oversampled(sprite)`；角度为 0 时用不到
    static func placed(
        _ sprite: PixelSpriteGrid,
        oversampled: PixelSpriteGrid?,
        degrees: Int,
        pivot: CGPoint,
        origin: (x: Int, y: Int),
        canvasWidth: Int,
        canvasHeight: Int
    ) -> PixelSpriteGrid {
        var cells = [UInt32](repeating: PixelSpriteGrid.clear, count: canvasWidth * canvasHeight)
        guard degrees != 0, let oversampled else {
            for y in 0..<sprite.height where (0..<canvasHeight).contains(y + origin.y) {
                for x in 0..<sprite.width where (0..<canvasWidth).contains(x + origin.x) {
                    cells[(y + origin.y) * canvasWidth + x + origin.x] = sprite.cells[y * sprite.width + x]
                }
            }
            return PixelSpriteGrid(width: canvasWidth, height: canvasHeight, cells: cells)
        }
        let radians = Double(degrees) * .pi / 180
        let cosine = cos(radians), sine = sin(radians)
        /// 画布格中心反转回 sprite 上的位置（y 向下时，逆时针转 θ 的逆变换）
        func source(_ x: Int, _ y: Int) -> CGPoint {
            let dx = Double(x - origin.x) + 0.5 - pivot.x
            let dy = Double(y - origin.y) + 0.5 - pivot.y
            return CGPoint(x: cosine * dx - sine * dy + pivot.x, y: sine * dx + cosine * dy + pivot.y)
        }
        let factor = CGFloat(rotationOversample)
        let bigWidth = oversampled.width, bigHeight = oversampled.height
        oversampled.cells.withUnsafeBufferPointer { big in
            for y in 0..<canvasHeight {
                for x in 0..<canvasWidth {
                    let point = source(x, y)
                    let bx = Int((point.x * factor).rounded(.down)), by = Int((point.y * factor).rounded(.down))
                    guard bx >= 0, by >= 0, bx < bigWidth, by < bigHeight else { continue }
                    cells[y * canvasWidth + x] = big[by * bigWidth + bx]
                }
            }
        }
        let grid = PixelSpriteGrid(width: canvasWidth, height: canvasHeight, cells: cells)
        return repairingSilhouette(grid, from: sprite, source: source)
    }

    /// 转完后外轮廓偶尔会断一格，里面的毛色直接露在外面。
    /// 露在外面的格子，原图对应位置附近如果是轮廓格，就换成离它最近的那格轮廓色，外轮廓重新连成一圈
    private static func repairingSilhouette(
        _ grid: PixelSpriteGrid,
        from sprite: PixelSpriteGrid,
        source: (Int, Int) -> CGPoint
    ) -> PixelSpriteGrid {
        var cells = grid.cells
        for y in 0..<grid.height {
            for x in 0..<grid.width where grid.isOpaque(x: x, y: y) && isOnSilhouette(grid, x: x, y: y) {
                let cell = grid[x, y]
                let point = source(x, y)
                let baseX = Int(point.x.rounded(.down)), baseY = Int(point.y.rounded(.down))
                var nearest: (color: UInt32, distance: CGFloat)?
                var matchesOutline = false
                for dy in -1...1 {
                    for dx in -1...1 {
                        let sx = baseX + dx, sy = baseY + dy
                        guard sprite.isOpaque(x: sx, y: sy), isOnSilhouette(sprite, x: sx, y: sy) else { continue }
                        let color = sprite[sx, sy]
                        if color == cell { matchesOutline = true }
                        let distance = hypot(CGFloat(sx) + 0.5 - point.x, CGFloat(sy) + 0.5 - point.y)
                        if nearest.map({ distance < $0.distance }) ?? true { nearest = (color, distance) }
                    }
                }
                if !matchesOutline, let nearest { cells[y * grid.width + x] = nearest.color }
            }
        }
        return PixelSpriteGrid(width: grid.width, height: grid.height, cells: cells)
    }

    /// 不透明且上下左右至少一边透明：在外轮廓上
    private static func isOnSilhouette(_ grid: PixelSpriteGrid, x: Int, y: Int) -> Bool {
        !grid.isOpaque(x: x - 1, y: y) || !grid.isOpaque(x: x + 1, y: y)
            || !grid.isOpaque(x: x, y: y - 1) || !grid.isOpaque(x: x, y: y + 1)
    }
}
