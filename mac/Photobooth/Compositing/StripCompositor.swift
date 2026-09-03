import AppKit

enum StripCompositor {
    /// Composites up to `StripLayout.photoCount` photos and a frame template
    /// into the final strip image. Missing photos are drawn as light-grey
    /// placeholders (used for the live preview before all shots are taken).
    static func render(photos: [NSImage?], frame: FrameTemplate) -> NSImage {
        let w = Int(StripLayout.stripW)
        let h = Int(StripLayout.stripH)
        let image = NSImage(size: NSSize(width: w, height: h))

        image.lockFocus()
        defer { image.unlockFocus() }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

        ctx.saveGState()
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Flip once so (0,0) is the top-left and y grows downward,
        // matching the layout math shared with the web version.
        ctx.translateBy(x: 0, y: StripLayout.stripH)
        ctx.scaleBy(x: 1, y: -1)

        for i in 0..<StripLayout.photoCount {
            let rect = CGRect(x: StripLayout.pad, y: StripLayout.photoY[i], width: StripLayout.photoW, height: StripLayout.photoH)
            if let photo = i < photos.count ? photos[i] : nil,
               let cg = photo.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                ctx.saveGState()
                // Draw with a y-flip local to this image so it isn't upside down
                // (the outer context is already flipped once).
                ctx.translateBy(x: rect.minX, y: rect.minY + rect.height)
                ctx.scaleBy(x: 1, y: -1)
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
                ctx.restoreGState()
            } else {
                ctx.setFillColor(CGColor(gray: 0.9, alpha: 1))
                ctx.fill(rect)
            }
        }

        frame.draw(in: ctx)
        ctx.restoreGState()
        return image
    }
}
