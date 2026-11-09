import AppKit
import SwiftUI

/// `Radish --snapshot <dir>` renders every window page in light and dark to PNGs, then quits.
/// It reads saved screens and live displays but never creates a virtual screen.
@MainActor
enum Snapshots {
    static func run(into dir: URL) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let model = AppModel.shared
        var pages: [(String, AnyView, SidebarItem?)] = [("general", AnyView(RootView()), .general)]
        if let screen = model.screens.first { pages.append(("screen", AnyView(RootView()), .screen(screen.id))) }
        if let display = model.displays.first { pages.append(("display", AnyView(RootView()), .display(display.id))) }
        pages.append(("new-screen", AnyView(NewScreenSheet {}), nil))

        var jobs: [() -> Void] = []
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            for (name, view, selection) in pages {
                jobs.append {
                    if let selection { model.selection = selection }
                    let size = selection == nil ? NSSize(width: 440, height: 560) : NSSize(width: 860, height: 960)
                    let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -4000, y: -4000), size: size),
                                          styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: appearance)
                    window.contentViewController = NSHostingController(rootView: view)
                    window.setContentSize(size)
                    window.orderFrontRegardless()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if let frameView = window.contentView?.superview {
                            let suffix = appearance == .darkAqua ? "dark" : "light"
                            save(frameView, to: dir.appendingPathComponent("\(name)-\(suffix).png"))
                        }
                        window.orderOut(nil)
                    }
                }
            }
        }

        func next(_ index: Int) {
            guard index < jobs.count else { exit(0) }
            jobs[index]()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { next(index + 1) }
        }
        DispatchQueue.main.async { next(0) }
        app.run()
    }

    private static func save(_ view: NSView, to url: URL) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
