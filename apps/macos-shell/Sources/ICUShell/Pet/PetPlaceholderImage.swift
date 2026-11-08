import AppKit

enum PetPlaceholderImage {
    /// 内置占位图：程序化绘制水豚
    static func make() -> NSImage {
        let size = NSSize(width: 128, height: 128)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let cx = rect.midX, cy = rect.midY - 4
            let bRX: CGFloat = 44, bRY: CGFloat = 32, hR: CGFloat = 32
            let cs = CGColorSpaceCreateDeviceRGB()

            // 身体
            ctx.setFillColor(NSColor(calibratedRed:0.58,green:0.48,blue:0.36,alpha:1).cgColor)
            ctx.fillEllipse(in: CGRect(x:cx-bRX,y:cy-bRY,width:bRX*2,height:bRY*2))
            // 身体渐变高光
            if let g = CGGradient(colorsSpace:cs,
                colors:[NSColor(calibratedRed:0.78,green:0.68,blue:0.52,alpha:0.55).cgColor,
                        NSColor.clear.cgColor] as CFArray, locations:[0,1]) {
                ctx.saveGState()
                ctx.addEllipse(in:CGRect(x:cx-bRX,y:cy-bRY,width:bRX*2,height:bRY*2)); ctx.clip()
                ctx.drawLinearGradient(g,start:CGPoint(x:cx,y:cy+bRY),end:CGPoint(x:cx,y:cy-bRY),options:[])
                ctx.restoreGState()
            }
            // 腹部
            ctx.setFillColor(NSColor(calibratedRed:0.82,green:0.74,blue:0.60,alpha:0.55).cgColor)
            ctx.fillEllipse(in:CGRect(x:cx-20,y:cy-24,width:40,height:34))

            // 腿
            ctx.setFillColor(NSColor(calibratedRed:0.50,green:0.40,blue:0.28,alpha:1).cgColor)
            for (lx,ly) in [(cx-26,cy-bRY+3),(cx-10,cy-bRY+1),(cx+10,cy-bRY+1),(cx+26,cy-bRY+3)] as [(CGFloat,CGFloat)] {
                ctx.fillEllipse(in:CGRect(x:lx-7,y:ly-13,width:14,height:14))
            }

            // 头
            let hCY = cy + bRY*0.5 + hR*0.55
            ctx.setFillColor(NSColor(calibratedRed:0.60,green:0.50,blue:0.38,alpha:1).cgColor)
            ctx.fillEllipse(in:CGRect(x:cx-hR,y:hCY-hR*0.85,width:hR*2,height:hR*1.7))

            // 耳朵
            for (ex,ey) in [(cx-hR*0.62,hCY+hR*0.68),(cx+hR*0.62,hCY+hR*0.68)] as [(CGFloat,CGFloat)] {
                ctx.setFillColor(NSColor(calibratedRed:0.52,green:0.42,blue:0.30,alpha:1).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-10,y:ey-7,width:20,height:16))
                ctx.setFillColor(NSColor(calibratedRed:0.88,green:0.64,blue:0.60,alpha:0.7).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-5,y:ey-3,width:10,height:8))
            }

            // 眼白→瞳孔→高光
            for ex in [cx-hR*0.36, cx+hR*0.36] as [CGFloat] {
                let ey = hCY+hR*0.10
                ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-8,y:ey-7,width:16,height:15))
                ctx.setFillColor(NSColor(calibratedRed:0.10,green:0.07,blue:0.04,alpha:1).cgColor)
                ctx.fillEllipse(in:CGRect(x:ex-5,y:ey-5,width:10,height:11))
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fillEllipse(in:CGRect(x:ex+1,y:ey+1,width:4,height:4))
            }

            // 鼻子
            ctx.setFillColor(NSColor(calibratedRed:0.35,green:0.25,blue:0.16,alpha:1).cgColor)
            ctx.fillEllipse(in:CGRect(x:cx-9,y:hCY-hR*0.28,width:18,height:11))
            ctx.setFillColor(NSColor(calibratedRed:0.20,green:0.12,blue:0.07,alpha:0.8).cgColor)
            for nx in [cx-3.5,cx+3.5] as [CGFloat] {
                ctx.fillEllipse(in:CGRect(x:nx-2,y:hCY-hR*0.26,width:4,height:3.5))
            }

            // 嘴
            ctx.setStrokeColor(NSColor(calibratedRed:0.28,green:0.18,blue:0.10,alpha:0.7).cgColor)
            ctx.setLineWidth(1.5); ctx.setLineCap(.round)
            ctx.move(to:CGPoint(x:cx-5,y:hCY-hR*0.42))
            ctx.addCurve(to:CGPoint(x:cx+5,y:hCY-hR*0.42),
                         control1:CGPoint(x:cx-2,y:hCY-hR*0.52),
                         control2:CGPoint(x:cx+2,y:hCY-hR*0.52))
            ctx.strokePath()

            // 毛发纹理
            ctx.setStrokeColor(NSColor(calibratedRed:0.70,green:0.58,blue:0.42,alpha:0.32).cgColor)
            ctx.setLineWidth(1.0)
            for _ in 0..<22 {
                let a = CGFloat.random(in:0...(.pi*2))
                let r = CGFloat.random(in:bRX*0.4...bRX*0.8)
                let sx = cx+cos(a)*r, sy = cy+sin(a)*r*(bRY/bRX)
                ctx.move(to:CGPoint(x:sx,y:sy))
                ctx.addLine(to:CGPoint(x:sx+cos(a)*4,y:sy+sin(a)*4))
                ctx.strokePath()
            }

            // 腮红
            ctx.setFillColor(NSColor(calibratedRed:0.95,green:0.55,blue:0.55,alpha:0.25).cgColor)
            for bx in [cx-hR*0.66, cx+hR*0.66] as [CGFloat] {
                ctx.fillEllipse(in:CGRect(x:bx-10,y:hCY-hR*0.06,width:20,height:12))
            }
            return true
        }
        return image
    }
}
