import AppKit
import SwiftUI

/// The Radish window. While it's open Radish shows in the Dock like a normal app;
/// when it closes Radish goes back to living in the menu bar.
@MainActor
final class MainWindow: NSObject, NSWindowDelegate {
    static let shared = MainWindow()
    private var window: NSWindow?

    func show(_ selection: SidebarItem? = nil) {
        if let selection { AppModel.shared.selection = selection }
        AppModel.shared.refresh()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.title = "Radish"
        window.contentViewController = NSHostingController(rootView: RootView())
        window.setContentSize(NSSize(width: 860, height: 580))
        window.minSize = NSSize(width: 700, height: 480)
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("RadishMainWindow")
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// A minimal main menu for while the window is open. The Edit menu is what makes
/// copy and paste work in text fields.
@MainActor
enum MainMenu {
    static func install() {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: "About Radish", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Radish", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Quit Radish", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu(app, "Radish"))

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu(edit, "Edit"))

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(submenu(window, "Window"))
        NSApp.windowsMenu = window

        NSApp.mainMenu = main
    }

    private static func submenu(_ menu: NSMenu, _ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
