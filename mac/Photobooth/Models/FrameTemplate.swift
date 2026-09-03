import AppKit

enum FrameTemplate: Identifiable, Equatable {
    case none
    case classic
    case polaroid
    case confetti
    case custom(NSImage)

    var id: String {
        switch self {
        case .none: return "none"
        case .classic: return "classic"
        case .polaroid: return "polaroid"
        case .confetti: return "confetti"
        case .custom: return "custom"
        }
    }

    var displayName: String {
        switch self {
        case .none: return "No frame"
        case .classic: return "Classic"
        case .polaroid: return "Polaroid"
        case .confetti: return "Confetti"
        case .custom: return "Custom"
        }
    }

    static func == (lhs: FrameTemplate, rhs: FrameTemplate) -> Bool { lhs.id == rhs.id }

    /// Draws this frame into a top-down (y increases downward) CGContext
    /// sized StripLayout.stripW × StripLayout.stripH.
    func draw(in ctx: CGContext) {
        switch self {
        case .none:
            break
        case .classic:
            FrameDrawing.drawClassic(in: ctx)
        case .polaroid:
            FrameDrawing.drawPolaroid(in: ctx)
        case .confetti:
            FrameDrawing.drawConfetti(in: ctx)
        case .custom(let image):
            let rect = CGRect(x: 0, y: 0, width: StripLayout.stripW, height: StripLayout.stripH)
            if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                ctx.draw(cg, in: rect)
            }
        }
    }

    /// A small thumbnail preview (for the picker), same aspect as the strip.
    func thumbnail(size: CGSize) -> NSImage {
        let scale = size.width / StripLayout.stripW
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return img }
        ctx.saveGState()
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.scaleBy(x: scale, y: scale)
        // flip to top-down coordinates matching draw(in:)
        ctx.translateBy(x: 0, y: StripLayout.stripH)
        ctx.scaleBy(x: 1, y: -1)
        draw(in: ctx)
        ctx.restoreGState()
        img.unlockFocus()
        return img
    }
}

private enum FrameDrawing {
    private static let gold = CGColor(red: 0.831, green: 0.686, blue: 0.216, alpha: 1)
    private static let ink = CGColor(red: 0.122, green: 0.122, blue: 0.169, alpha: 1)
    private static let mutedGrey = CGColor(red: 0.42, green: 0.42, blue: 0.47, alpha: 1)

    static func drawClassic(in ctx: CGContext) {
        let w = StripLayout.stripW, h = StripLayout.stripH
        ctx.setFillColor(ink)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: 15))
        ctx.fill(CGRect(x: 0, y: h - 15, width: w, height: 15))
        ctx.fill(CGRect(x: 0, y: 0, width: 15, height: h))
        ctx.fill(CGRect(x: w - 15, y: 0, width: 15, height: h))

        ctx.setStrokeColor(gold)
        ctx.setLineWidth(2)
        ctx.stroke(CGRect(x: 24, y: 24, width: w - 48, height: h - 48))

        ctx.setFillColor(gold)
        for gy in StripLayout.gapCenters {
            ctx.fill(CGRect(x: StripLayout.pad, y: gy - 1.5, width: StripLayout.photoW, height: 3))
        }

        let footerTop = StripLayout.footerTop
        ctx.setStrokeColor(gold)
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: StripLayout.pad, y: footerTop + 40))
        ctx.addLine(to: CGPoint(x: w - StripLayout.pad, y: footerTop + 40))
        ctx.strokePath()

        drawTopDownText("PHOTO BOOTH", at: CGPoint(x: w / 2, y: footerTop + 95), font: NSFont(name: "Georgia-Bold", size: 40) ?? .boldSystemFont(ofSize: 40), color: ink, centered: true, in: ctx)
        drawTopDownText("est. today", at: CGPoint(x: w / 2, y: footerTop + 140), font: NSFont(name: "Georgia", size: 21) ?? .systemFont(ofSize: 21), color: mutedGrey, centered: true, in: ctx)
    }

    static func drawPolaroid(in ctx: CGContext) {
        let w = StripLayout.stripW
        let tapeColors: [CGColor] = [
            CGColor(red: 0.965, green: 0.827, blue: 0.396, alpha: 0.85),
            CGColor(red: 0.631, green: 0.769, blue: 0.992, alpha: 0.85),
            CGColor(red: 0.984, green: 0.761, blue: 0.925, alpha: 0.85),
            CGColor(red: 0.765, green: 0.941, blue: 0.792, alpha: 0.85),
        ]
        var tapeCenters: [CGFloat] = []
        for i in 0..<StripLayout.photoCount {
            tapeCenters.append(i == 0 ? StripLayout.pad / 2 : StripLayout.gapCenters[i - 1])
        }

        for (i, tc) in tapeCenters.enumerated() {
            for cx in [StripLayout.pad + 70, w - StripLayout.pad - 70] {
                let angle: CGFloat = cx < w / 2 ? -8 : 8
                ctx.saveGState()
                ctx.translateBy(x: cx, y: tc)
                ctx.rotate(by: angle * .pi / 180)
                ctx.setFillColor(tapeColors[i % tapeColors.count])
                ctx.fill(CGRect(x: -45, y: -11, width: 90, height: 22))
                ctx.restoreGState()
            }
        }

        ctx.setFillColor(CGColor(red: 0.816, green: 0.816, blue: 0.855, alpha: 0.6))
        for y in StripLayout.photoY {
            for cx in [StripLayout.pad - 12, w - StripLayout.pad + 12] {
                let cy = cx > w / 2 ? y + StripLayout.photoH : y
                ctx.fillEllipse(in: CGRect(x: cx - 5, y: cy - 5, width: 10, height: 10))
            }
        }

        let footerTop = StripLayout.footerTop
        drawTopDownText("memories ♥", at: CGPoint(x: w / 2, y: footerTop + 75), font: NSFont(name: "Bradley Hand", size: 46) ?? .systemFont(ofSize: 46), color: CGColor(red: 0.227, green: 0.224, blue: 0.282, alpha: 1), centered: true, in: ctx)
        drawTopDownText("captured today", at: CGPoint(x: w / 2, y: footerTop + 120), font: .systemFont(ofSize: 18), color: mutedGrey, centered: true, in: ctx)
    }

    static func drawConfetti(in ctx: CGContext) {
        func color(_ c: ConfettiColor) -> CGColor {
            switch c {
            case .accent: return CGColor(red: 1, green: 0.365, blue: 0.635, alpha: 1)
            case .accent2: return CGColor(red: 0.486, green: 0.361, blue: 1, alpha: 1)
            case .yellow: return CGColor(red: 1, green: 0.820, blue: 0.4, alpha: 1)
            case .green: return CGColor(red: 0.024, green: 0.839, blue: 0.627, alpha: 1)
            case .blue: return CGColor(red: 0.298, green: 0.8, blue: 0.941, alpha: 1)
            }
        }
        for dot in ConfettiData.dots {
            ctx.setFillColor(color(dot.color))
            if dot.isCircle {
                ctx.fillEllipse(in: CGRect(x: dot.x - dot.r, y: dot.y - dot.r, width: dot.r * 2, height: dot.r * 2))
            } else {
                ctx.saveGState()
                ctx.translateBy(x: dot.x, y: dot.y)
                ctx.rotate(by: dot.rotationDeg * .pi / 180)
                let side = dot.r * 1.6
                ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
                ctx.restoreGState()
            }
        }
        let w = StripLayout.stripW
        drawTopDownText("PARTY TIME!", at: CGPoint(x: w / 2, y: StripLayout.footerTop + 205), font: .boldSystemFont(ofSize: 40), color: CGColor(red: 0.169, green: 0.165, blue: 0.220, alpha: 1), centered: true, in: ctx)
    }

    /// Draws text at a point given in the flipped (top-down) coordinate
    /// system used elsewhere in this file.
    private static func drawTopDownText(_ string: String, at point: CGPoint, font: NSFont, color: CGColor, centered: Bool, in ctx: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: color) ?? .black,
        ]
        let attributed = NSAttributedString(string: string, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        ctx.scaleBy(x: 1, y: -1) // undo the outer flip just for text, so glyphs aren't mirrored
        let x = centered ? -bounds.width / 2 : 0
        ctx.textPosition = CGPoint(x: x, y: 0)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
