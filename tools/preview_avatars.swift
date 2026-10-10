#!/usr/bin/env swift
// demo_avatars.swift — 水豚形象风格预览
// 运行: swift demo_avatars.swift

import AppKit
import QuartzCore

// MARK: - 各风格绘制函数

/// 风格1: Q弹水滴 (Core Graphics 径向渐变 + 透明质感)
func drawJellyCapybara(in ctx: CGContext, bounds: CGRect) {
    let cx = bounds.midX, cy = bounds.midY
    let r = min(bounds.width, bounds.height) * 0.42

    // 身体 — 圆形径向渐变
    let colors = [
        NSColor(calibratedRed: 0.55, green: 0.82, blue: 0.95, alpha: 0.92).cgColor,
        NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.78, alpha: 0.96).cgColor,
    ]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0])!
    ctx.saveGState()
    let bodyPath = CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r * 1.05, width: r * 2, height: r * 2.1), transform: nil)
    ctx.addPath(bodyPath); ctx.clip()
    ctx.drawRadialGradient(gradient,
        startCenter: CGPoint(x: cx - r * 0.25, y: cy + r * 0.35), startRadius: 0,
        endCenter: CGPoint(x: cx, y: cy), endRadius: r * 1.4,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // 高光
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.45).cgColor)
    let hlPath = CGPath(ellipseIn: CGRect(x: cx - r * 0.55, y: cy + r * 0.15, width: r * 0.7, height: r * 0.38), transform: nil)
    ctx.addPath(hlPath); ctx.fillPath()

    // 耳朵
    for dx in [-0.55, 0.55] as [CGFloat] {
        let ep = CGPath(ellipseIn: CGRect(x: cx + dx * r - r * 0.17, y: cy + r * 0.72, width: r * 0.34, height: r * 0.28), transform: nil)
        ctx.setFillColor(NSColor(calibratedRed: 0.38, green: 0.65, blue: 0.88, alpha: 1.0).cgColor)
        ctx.addPath(ep); ctx.fillPath()
        let epi = CGPath(ellipseIn: CGRect(x: cx + dx * r - r * 0.1, y: cy + r * 0.76, width: r * 0.2, height: r * 0.16), transform: nil)
        ctx.setFillColor(NSColor(calibratedRed: 0.85, green: 0.55, blue: 0.72, alpha: 0.8).cgColor)
        ctx.addPath(epi); ctx.fillPath()
    }
    // 眼睛
    for dx in [-0.28, 0.28] as [CGFloat] {
        ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor)
        let ep = CGPath(ellipseIn: CGRect(x: cx + dx * r - r * 0.13, y: cy - r * 0.05, width: r * 0.26, height: r * 0.3), transform: nil)
        ctx.addPath(ep); ctx.fillPath()
        ctx.setFillColor(NSColor.white.cgColor)
        let hl = CGPath(ellipseIn: CGRect(x: cx + dx * r - r * 0.03, y: cy + r * 0.08, width: r * 0.1, height: r * 0.1), transform: nil)
        ctx.addPath(hl); ctx.fillPath()
    }
    // 鼻子
    ctx.setFillColor(NSColor(calibratedRed: 0.2, green: 0.35, blue: 0.55, alpha: 0.8).cgColor)
    let np = CGPath(ellipseIn: CGRect(x: cx - r * 0.12, y: cy - r * 0.22, width: r * 0.24, height: r * 0.14), transform: nil)
    ctx.addPath(np); ctx.fillPath()
    // 腮红
    for dx in [-0.44, 0.44] as [CGFloat] {
        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.65, alpha: 0.35).cgColor)
        let bp = CGPath(ellipseIn: CGRect(x: cx + dx * r - r * 0.2, y: cy - r * 0.2, width: r * 0.4, height: r * 0.22), transform: nil)
        ctx.addPath(bp); ctx.fillPath()
    }
}

/// 风格2: 毛球水豚 (放射状笔触模拟绒毛)
func drawFurryCapybara(in ctx: CGContext, bounds: CGRect) {
    let cx = bounds.midX, cy = bounds.midY
    let r = min(bounds.width, bounds.height) * 0.38

    // 底色球体
    ctx.setFillColor(NSColor(calibratedRed: 0.72, green: 0.55, blue: 0.38, alpha: 1.0).cgColor)
    ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2))

    // 绒毛：放射状短线
    ctx.setStrokeColor(NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.52, alpha: 0.7).cgColor)
    ctx.setLineWidth(1.2)
    for i in stride(from: 0.0, to: 360.0, by: 7.0) {
        let angle = CGFloat(i) * .pi / 180
        let jitter = CGFloat.random(in: 0.88...1.12)
        let x1 = cx + cos(angle) * r * 0.82 * jitter
        let y1 = cy + sin(angle) * r * 0.82 * jitter
        let x2 = cx + cos(angle) * (r + CGFloat.random(in: 4...10))
        let y2 = cy + sin(angle) * (r + CGFloat.random(in: 4...10))
        ctx.move(to: CGPoint(x: x1, y: y1))
        ctx.addLine(to: CGPoint(x: x2, y: y2))
        ctx.strokePath()
    }
    // 肚皮浅色
    ctx.setFillColor(NSColor(calibratedRed: 0.92, green: 0.82, blue: 0.68, alpha: 0.85).cgColor)
    ctx.fillEllipse(in: CGRect(x: cx - r*0.5, y: cy - r*0.55, width: r*1.0, height: r*1.1))

    // 耳朵
    for dx in [-1.0, 1.0] as [CGFloat] {
        ctx.setFillColor(NSColor(calibratedRed: 0.62, green: 0.44, blue: 0.28, alpha: 1.0).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + dx*(r*0.62) - r*0.2, y: cy + r*0.62, width: r*0.4, height: r*0.32))
        ctx.setFillColor(NSColor(calibratedRed: 0.92, green: 0.62, blue: 0.68, alpha: 0.9).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + dx*(r*0.62) - r*0.11, y: cy + r*0.67, width: r*0.22, height: r*0.18))
    }
    // 眼睛 (弯月)
    ctx.setStrokeColor(NSColor(white: 0.1, alpha: 1).cgColor)
    ctx.setLineWidth(2.5)
    for dx in [-0.3, 0.3] as [CGFloat] {
        ctx.move(to: CGPoint(x: cx + dx*r - r*0.15, y: cy + r*0.1))
        ctx.addArc(center: CGPoint(x: cx + dx*r, y: cy + r*0.18), radius: r*0.18, startAngle: .pi*1.1, endAngle: .pi*1.9, clockwise: false)
        ctx.strokePath()
    }
    // 鼻子
    ctx.setFillColor(NSColor(calibratedRed: 0.4, green: 0.22, blue: 0.12, alpha: 0.9).cgColor)
    ctx.fillEllipse(in: CGRect(x: cx - r*0.14, y: cy - r*0.08, width: r*0.28, height: r*0.16))
    // 腮红
    for dx in [-0.48, 0.48] as [CGFloat] {
        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.5, alpha: 0.3).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + dx*r - r*0.22, y: cy - r*0.12, width: r*0.44, height: r*0.24))
    }
}

/// 风格3: 3D伪球体水豚 (高光+反射)
func draw3DCapybara(in ctx: CGContext, bounds: CGRect) {
    let cx = bounds.midX, cy = bounds.midY
    let r = min(bounds.width, bounds.height) * 0.4

    // 倒影
    ctx.saveGState()
    ctx.setAlpha(0.18)
    ctx.scaleBy(x: 1.0, y: -0.22)
    let shadowY = -(cy - r) * 2 + cy
    let cs = CGColorSpaceCreateDeviceRGB()
    let sc = [NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.22, alpha: 0.8).cgColor,
              NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.22, alpha: 0.0).cgColor] as CFArray
    let sg = CGGradient(colorsSpace: cs, colors: sc, locations: [0, 1])!
    ctx.drawLinearGradient(sg,
        start: CGPoint(x: cx, y: shadowY),
        end: CGPoint(x: cx, y: shadowY - r*0.8), options: [])
    ctx.restoreGState()

    // 球体渐变
    let bodyColors = [
        NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.52, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.48, green: 0.30, blue: 0.14, alpha: 1.0).cgColor,
    ]
    let cs2 = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs2, colors: bodyColors as CFArray, locations: [0, 1.0])!
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx-r, y: cy-r, width: r*2, height: r*2))
    ctx.clip()
    ctx.drawRadialGradient(grad,
        startCenter: CGPoint(x: cx - r*0.3, y: cy + r*0.3), startRadius: 0,
        endCenter: CGPoint(x: cx, y: cy), endRadius: r*1.4,
        options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // 主高光
    ctx.saveGState()
    let hlColors = [NSColor.white.withAlphaComponent(0.72).cgColor,
                    NSColor.white.withAlphaComponent(0.0).cgColor] as CFArray
    let hlGrad = CGGradient(colorsSpace: cs2, colors: hlColors, locations: [0, 1])!
    ctx.addEllipse(in: CGRect(x: cx - r*0.55, y: cy + r*0.2, width: r*0.65, height: r*0.42))
    ctx.clip()
    ctx.drawRadialGradient(hlGrad,
        startCenter: CGPoint(x: cx - r*0.3, y: cy + r*0.38), startRadius: 0,
        endCenter: CGPoint(x: cx - r*0.28, y: cy + r*0.32), endRadius: r*0.42,
        options: [.drawsAfterEndLocation])
    ctx.restoreGState()

    // 耳朵
    for dx in [-0.58, 0.58] as [CGFloat] {
        ctx.setFillColor(NSColor(calibratedRed: 0.62, green: 0.44, blue: 0.26, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx+dx*r - r*0.18, y: cy+r*0.68, width: r*0.36, height: r*0.28))
    }
    // 眼睛 (大黑眼珠+高光+环境光)
    for dx in [-0.3, 0.3] as [CGFloat] {
        ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx+dx*r - r*0.15, y: cy - r*0.08, width: r*0.3, height: r*0.32))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx+dx*r - r*0.02, y: cy + r*0.08, width: r*0.1, height: r*0.1))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx+dx*r - r*0.12, y: cy - r*0.02, width: r*0.07, height: r*0.07))
    }
    // 鼻子
    ctx.setFillColor(NSColor(calibratedRed: 0.28, green: 0.14, blue: 0.06, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: cx - r*0.16, y: cy - r*0.18, width: r*0.32, height: r*0.18))
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
    ctx.fillEllipse(in: CGRect(x: cx - r*0.08, y: cy - r*0.14, width: r*0.1, height: r*0.06))
}

/// 风格4: 极简线条水豚 (描边 + 扁平)
func drawMinimalCapybara(in ctx: CGContext, bounds: CGRect) {
    let cx = bounds.midX, cy = bounds.midY
    let r = min(bounds.width, bounds.height) * 0.38

    ctx.setLineWidth(3.5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // 身体
    ctx.setFillColor(NSColor(calibratedRed: 0.98, green: 0.92, blue: 0.82, alpha: 1.0).cgColor)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.3, green: 0.2, blue: 0.1, alpha: 1.0).cgColor)
    let bodyRect = CGRect(x: cx - r*1.05, y: cy - r*0.75, width: r*2.1, height: r*1.6)
    let bodyPath = UIBezierLikePath.roundedRect(bodyRect, cornerRadius: r*0.7)
    ctx.addPath(bodyPath); ctx.drawPath(using: .fillStroke)

    // 头
    ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.87, blue: 0.73, alpha: 1.0).cgColor)
    ctx.addEllipse(in: CGRect(x: cx - r*0.72, y: cy - r*0.55, width: r*1.44, height: r*1.2))
    ctx.drawPath(using: .fillStroke)

    // 耳朵
    ctx.setFillColor(NSColor(calibratedRed: 0.95, green: 0.87, blue: 0.73, alpha: 1.0).cgColor)
    for dx in [-0.5, 0.5] as [CGFloat] {
        ctx.addEllipse(in: CGRect(x: cx + dx*r*0.65 - r*0.22, y: cy + r*0.55, width: r*0.44, height: r*0.36))
        ctx.drawPath(using: .fillStroke)
    }
    // 眼睛
    ctx.setFillColor(NSColor(white: 0.1, alpha: 1).cgColor)
    for dx in [-0.28, 0.28] as [CGFloat] {
        ctx.fillEllipse(in: CGRect(x: cx + dx*r - r*0.12, y: cy - r*0.05, width: r*0.24, height: r*0.26))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + dx*r + r*0.01, y: cy + r*0.06, width: r*0.08, height: r*0.08))
        ctx.setFillColor(NSColor(white: 0.1, alpha: 1).cgColor)
    }
    // 鼻孔
    ctx.setFillColor(NSColor(calibratedRed: 0.3, green: 0.2, blue: 0.1, alpha: 0.6).cgColor)
    for dx in [-0.1, 0.1] as [CGFloat] {
        ctx.fillEllipse(in: CGRect(x: cx + dx*r - r*0.055, y: cy - r*0.22, width: r*0.11, height: r*0.1))
    }
    // 嘴
    ctx.setStrokeColor(NSColor(calibratedRed: 0.3, green: 0.2, blue: 0.1, alpha: 0.8).cgColor)
    ctx.setLineWidth(2.5)
    ctx.move(to: CGPoint(x: cx - r*0.18, y: cy - r*0.32))
    ctx.addArc(center: CGPoint(x: cx, y: cy - r*0.4), radius: r*0.2, startAngle: .pi*1.35, endAngle: .pi*1.65, clockwise: false)
    ctx.strokePath()
    // 腮红
    for dx in [-0.44, 0.44] as [CGFloat] {
        ctx.setFillColor(NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.55, alpha: 0.35).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + dx*r - r*0.22, y: cy - r*0.28, width: r*0.44, height: r*0.24))
    }
}

// 辅助：简单圆角矩形 path
enum UIBezierLikePath {
    static func roundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        return path
    }
}

// MARK: - 预览窗口

class PreviewView: NSView {
    let styles: [(String, (CGContext, CGRect) -> Void)] = [
        ("Q弹水滴", drawJellyCapybara),
        ("毛球绒毛", drawFurryCapybara),
        ("3D伪球体", draw3DCapybara),
        ("极简线条", drawMinimalCapybara),
    ]

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // 背景
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        dirtyRect.fill()

        let cols = 2
        let cellW = bounds.width / CGFloat(cols)
        let cellH = bounds.height / CGFloat((styles.count + 1) / cols)

        for (i, (name, drawFn)) in styles.enumerated() {
            let col = i % cols
            let row = i / cols
            let cellRect = CGRect(x: CGFloat(col) * cellW, y: bounds.height - CGFloat(row + 1) * cellH,
                                  width: cellW, height: cellH)

            // 卡片背景
            ctx.setFillColor(NSColor(calibratedWhite: 0.18, alpha: 1).cgColor)
            ctx.fill(cellRect.insetBy(dx: 12, dy: 12))

            // 绘制形象
            let drawArea = cellRect.insetBy(dx: 24, dy: 24)
            ctx.saveGState()
            ctx.clip(to: drawArea)
            drawFn(ctx, drawArea)
            ctx.restoreGState()

            // 标签
            let label = name as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor(calibratedWhite: 0.85, alpha: 1),
                .font: NSFont.systemFont(ofSize: 13, weight: .medium)
            ]
            let labelSize = label.size(withAttributes: attrs)
            label.draw(at: CGPoint(x: cellRect.midX - labelSize.width/2,
                                   y: cellRect.minY + 16), withAttributes: attrs)
        }
    }
}

// MARK: - 启动

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
)
window.title = "水豚形象风格预览 — 选择你喜欢的风格"
window.center()

let view = PreviewView(frame: NSRect(x: 0, y: 0, width: 560, height: 520))
window.contentView = view
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
