// SPDX-License-Identifier: GPL-3.0-only
import AppKit

@MainActor enum CupIcon {
    static func image(isOn: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            // Keep the cup at the same position in both states.
            let offset = NSAffineTransform()
            offset.translateX(by: 0.3125, yBy: 0.375)
            offset.concat()
            NSColor.black.set()
            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: 12.5, y: 10.5))
            handle.curve(to: NSPoint(x: 12.5, y: 5.5),
                         controlPoint1: NSPoint(x: 17, y: 10.5),
                         controlPoint2: NSPoint(x: 17, y: 5.5))
            handle.lineWidth = 1.5
            handle.stroke()
            let cup = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 4, width: 11, height: 8),
                                   xRadius: 2, yRadius: 2)
            NSGraphicsContext.saveGraphicsState()
            cup.addClip()
            if isOn {
                NSBezierPath(rect: NSRect(x: 2.5, y: 5, width: 9, height: 6)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            cup.lineWidth = 1.5
            cup.stroke()
            for x in (isOn ? [CGFloat(4.5), CGFloat(8.5)] : []) {
                let steam = NSBezierPath()
                steam.move(to: NSPoint(x: x, y: 13.8))
                steam.curve(to: NSPoint(x: x, y: 17),
                            controlPoint1: NSPoint(x: x - 1.2, y: 14.8),
                            controlPoint2: NSPoint(x: x + 1.2, y: 16))
                steam.lineWidth = 1
                steam.lineCapStyle = .round
                steam.stroke()
            }
            let saucer = NSBezierPath()
            saucer.move(to: NSPoint(x: 1, y: 1.5))
            saucer.line(to: NSPoint(x: 14, y: 1.5))
            saucer.lineWidth = 1.5
            saucer.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
