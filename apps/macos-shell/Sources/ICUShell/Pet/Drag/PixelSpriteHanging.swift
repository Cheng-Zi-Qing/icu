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

    /// 脑袋原样，身体拉到 `stretchedBodyRows` 行，越往下越细，到脚底横向收成 1 / 拉长量^slimming
    static func hanging(
        _ sprite: PixelSpriteGrid,
        headRows: Int,
        stretchedBodyRows: Int,
        slimming: CGFloat
    ) -> PixelSpriteGrid {
        let headRows = min(max(headRows, 0), sprite.height)
        let bodyRows = sprite.height - headRows
        guard bodyRows > 0, stretchedBodyRows > 0 else { return sprite }
        let stretch = CGFloat(stretchedBodyRows) / CGFloat(bodyRows)
        let feetScale = 1 / pow(max(stretch, 1), slimming)
        let center = CGFloat(sprite.width) / 2
        let head = Array(sprite.cells[0..<(headRows * sprite.width)])
        let body = (0..<stretchedBodyRows).flatMap { row -> [UInt32] in
            let sourceRow = headRows + endpointIndex(row, from: stretchedBodyRows, to: bodyRows)
            // 第 0 行（紧挨脖子）几乎不收，最后一行收到 feetScale
            let progress = CGFloat(row) / CGFloat(max(stretchedBodyRows - 1, 1))
            let scale = 1 - (1 - feetScale) * progress
            return taperedRow(sprite, row: sourceRow, scale: scale, center: center)
        }
        return PixelSpriteGrid(width: sprite.width, height: headRows + stretchedBodyRows, cells: head + body)
    }

    /// 把一行的不透明部分围绕 center 收窄到 scale：两端的描边格一定留着，中间按整格挑
    private static func taperedRow(_ sprite: PixelSpriteGrid, row: Int, scale: CGFloat, center: CGFloat) -> [UInt32] {
        guard let span = sprite.opaqueSpan(row: row) else {
            return Array(repeating: PixelSpriteGrid.clear, count: sprite.width)
        }
        let left = Int((center - (center - CGFloat(span.lowerBound)) * scale).rounded())
        let right = max(left, Int((center + (CGFloat(span.upperBound + 1) - center) * scale).rounded()) - 1)
        return (0..<sprite.width).map { x in
            guard x >= left, x <= right else { return PixelSpriteGrid.clear }
            let source = span.lowerBound + endpointIndex(x - left, from: right - left + 1, to: span.count)
            return sprite[source, row]
        }
    }

    /// 把 0..<from 的下标按比例对到 0..<to，两头的端点一一对上
    static func endpointIndex(_ index: Int, from: Int, to: Int) -> Int {
        guard from > 1, to > 1 else { return 0 }
        return Int((Double(index) * Double(to - 1) / Double(from - 1)).rounded())
    }

    // MARK: - 甩动（RotSprite）

    /// Scale2x：一格变 2×2，斜边上的阶梯补齐成更顺的斜线，不引入新颜色
    static func scale2x(_ grid: PixelSpriteGrid) -> PixelSpriteGrid {
        let width = grid.width * 2
        let cells = (0..<(grid.height * 2)).flatMap { y in
            (0..<width).map { x -> UInt32 in
                let sx = x / 2, sy = y / 2
                let center = grid[sx, sy]
                let up = grid[sx, sy - 1], down = grid[sx, sy + 1]
                let left = grid[sx - 1, sy], right = grid[sx + 1, sy]
                // 每个子格只看它那个角挨着的两条边
                let vertical = y % 2 == 0 ? up : down
                let horizontal = x % 2 == 0 ? left : right
                let oppositeVertical = y % 2 == 0 ? down : up
                let oppositeHorizontal = x % 2 == 0 ? right : left
                let corner = vertical == horizontal && vertical != oppositeVertical && horizontal != oppositeHorizontal
                return corner ? vertical : center
            }
        }
        return PixelSpriteGrid(width: width, height: grid.height * 2, cells: cells)
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
        guard degrees != 0, let oversampled else {
            let cells = (0..<canvasHeight).flatMap { y in
                (0..<canvasWidth).map { x in sprite[x - origin.x, y - origin.y] }
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
        let swung = (0..<canvasHeight).flatMap { y in
            (0..<canvasWidth).map { x -> UInt32 in
                let point = source(x, y)
                return oversampled[Int((point.x * factor).rounded(.down)), Int((point.y * factor).rounded(.down))]
            }
        }
        let grid = PixelSpriteGrid(width: canvasWidth, height: canvasHeight, cells: swung)
        return repairingSilhouette(grid, from: sprite, source: source)
    }

    /// 转完后外轮廓偶尔会断一格，里面的毛色直接露在外面。
    /// 露在外面的格子，原图对应位置附近如果是轮廓格，就换成离它最近的那格轮廓色，外轮廓重新连成一圈
    private static func repairingSilhouette(
        _ grid: PixelSpriteGrid,
        from sprite: PixelSpriteGrid,
        source: (Int, Int) -> CGPoint
    ) -> PixelSpriteGrid {
        let cells = (0..<grid.height).flatMap { y in
            (0..<grid.width).map { x -> UInt32 in
                let cell = grid[x, y]
                guard grid.isOpaque(x: x, y: y), isOnSilhouette(grid, x: x, y: y) else { return cell }
                let point = source(x, y)
                let nearby = (-1...1).flatMap { dy in
                    (-1...1).map { dx in (x: Int(point.x.rounded(.down)) + dx, y: Int(point.y.rounded(.down)) + dy) }
                }
                .filter { sprite.isOpaque(x: $0.x, y: $0.y) && isOnSilhouette(sprite, x: $0.x, y: $0.y) }
                guard !nearby.isEmpty, !nearby.contains(where: { sprite[$0.x, $0.y] == cell }) else { return cell }
                let nearest = nearby.min { a, b in
                    hypot(CGFloat(a.x) + 0.5 - point.x, CGFloat(a.y) + 0.5 - point.y)
                        < hypot(CGFloat(b.x) + 0.5 - point.x, CGFloat(b.y) + 0.5 - point.y)
                }
                return nearest.map { sprite[$0.x, $0.y] } ?? cell
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
