import AppKit

// `Radish --list-displays` prints every online display and its modes, then exits.
// Handy for checking what a virtual screen actually exposes.
if CommandLine.arguments.contains("--list-displays") {
    DisplayReport.printAll()
    exit(0)
}

// `Radish --render-menubar-icon <dir>` writes the menu bar marks as PNGs for review.
if let index = CommandLine.arguments.firstIndex(of: "--render-menubar-icon"), index + 1 < CommandLine.arguments.count {
    let dir = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    for (name, filled) in [("on", true), ("off", false)] {
        for scale in [1, 2] {
            let image = MenuBarIcon.image(filled: filled)
            let px = 18 * scale
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = NSSize(width: 18, height: 18)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            image.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            NSGraphicsContext.restoreGraphicsState()
            try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("menubar-\(name)@\(scale)x.png"))
        }
    }
    exit(0)
}

if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
    MainActor.assumeIsolated { Snapshots.run(into: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
