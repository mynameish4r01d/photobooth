import CoreGraphics

/// Pixel layout for the photo strip. Matches the web version's canvas
/// exactly (600×2040) so a frame PNG exported for one works in the other.
enum StripLayout {
    static let photoCount = 4
    static let stripW: CGFloat = 600
    static let pad: CGFloat = 40
    static let photoW: CGFloat = stripW - pad * 2 // 520
    static let photoH: CGFloat = (photoW * 3 / 4).rounded() // 390, 4:3
    static let gap: CGFloat = 30
    static let footerH: CGFloat = 350

    static let photoY: [CGFloat] = (0..<photoCount).map { pad + CGFloat($0) * (photoH + gap) }
    static let footerTop: CGFloat = photoY.last! + photoH
    static let stripH: CGFloat = footerTop + footerH // 2040
    static let gapCenters: [CGFloat] = (0..<photoCount - 1).map { i in
        (photoY[i] + photoH + photoY[i + 1]) / 2
    }
}
