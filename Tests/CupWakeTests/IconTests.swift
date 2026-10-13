// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Testing
@testable import CupWake

@Suite("Cup artwork") @MainActor struct IconTests {
    @Test func nativeCupHasDistinctStatesAtBothScales() throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(".build/icon-previews")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var previews: [(Bool, Int, NSBitmapImageRep)] = []
        for scale in [1, 2] {
            var ink: [Int] = []
            for isOn in [false, true] {
                let image = CupIcon.image(isOn: isOn)
                #expect(image.isTemplate)
                let size = 18 * scale
                let bitmap = try #require(NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
                let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
                NSGraphicsContext.restoreGraphicsState()
                var total = 0
                for y in 0..<size {
                    for x in 0..<size {
                        total += Int((bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) * 255)
                    }
                }
                ink.append(total)
                previews.append((isOn, scale, bitmap))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: directory.appendingPathComponent("\(isOn ? "On" : "Off")-\(scale)x.png"))
            }
            #expect(ink[0] > 0)
            #expect(ink[1] > ink[0])
        }
        try writeGallery(previews, to: directory.appendingPathComponent("cups.png"))
    }

    private func writeGallery(_ previews: [(Bool, Int, NSBitmapImageRep)], to url: URL) throws {
        let gallery = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 180, pixelsHigh: 150, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let context = try #require(NSGraphicsContext(bitmapImageRep: gallery))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        for dark in [false, true] {
            let origin: CGFloat = dark ? 0 : 75
            (dark ? NSColor.black : NSColor.white).setFill()
            NSBezierPath(rect: NSRect(x: 0, y: origin, width: 180, height: 75)).fill()
            let foreground = dark ? NSColor.white : NSColor.black
            for (isOn, scale, bitmap) in previews {
                let column = isOn ? 1 : 0
                let left = CGFloat(column * 90 + (scale == 1 ? 16 : 43))
                let side = CGFloat(18 * scale)
                let rect = NSRect(x: left, y: origin + 13, width: side, height: side)
                let image = try #require(bitmap.cgImage)
                context.cgContext.saveGState()
                context.cgContext.clip(to: rect, mask: image)
                foreground.setFill()
                NSBezierPath(rect: rect).fill()
                context.cgContext.restoreGState()
                if scale == 1 {
                    ((isOn ? "On" : "Off") as NSString).draw(at: NSPoint(x: CGFloat(column * 90 + 12),
                                                                 y: origin + 57), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 10), .foregroundColor: foreground
                    ])
                }
            }
        }
        let png = try #require(gallery.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
