import AppKit

/// The menu bar mark: a radish, solid when a virtual screen is connected and hollow when not.
/// Drawn in code as a template image so it follows the menu bar's light and dark styles.
enum MenuBarIcon {
    static func image(filled: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()

            // Root: a round bulb with a pointed tip at the bottom.
            let bulb = NSBezierPath(ovalIn: NSRect(x: 4.5, y: 2.2, width: 9.0, height: 8.4))
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: 7.6, y: 2.8))
            tail.line(to: NSPoint(x: 9, y: 0.2))
            tail.line(to: NSPoint(x: 10.4, y: 2.8))
            tail.close()
            if filled {
                bulb.fill()
            } else {
                bulb.lineWidth = 1.3
                var inset = AffineTransform()
                inset.translate(x: 9, y: 6.4)
                inset.scale(0.86)
                inset.translate(x: -9, y: -6.4)
                bulb.transform(using: inset)
                bulb.stroke()
            }
            tail.fill()

            // Three leaves fanning out above the bulb, clear of it so they read at 1x.
            for (angle, start, length) in [(48.0, 1.0, 5.2), (0.0, 0.8, 5.6), (-48.0, 1.0, 5.2)] {
                let leaf = NSBezierPath(ovalIn: NSRect(x: -1.4, y: start, width: 2.8, height: length))
                var t = AffineTransform()
                t.translate(x: 9, y: 11.0)
                t.rotate(byDegrees: angle)
                leaf.transform(using: t)
                leaf.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = filled ? "Radish, virtual screen connected" : "Radish"
        return image
    }
}
