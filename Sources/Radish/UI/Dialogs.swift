import AppKit

@MainActor
enum Dialogs {
    private static let askedLoginKey = "askedLaunchAtLogin"

    /// A virtual screen only exists while Radish runs, so offer launch at login once.
    static func offerLaunchAtLogin() {
        guard !LaunchAtLogin.isEnabled, !UserDefaults.standard.bool(forKey: askedLoginKey) else { return }
        UserDefaults.standard.set(true, forKey: askedLoginKey)
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Open Radish at login?"
        alert.informativeText = "Virtual screens only exist while Radish is running. Launch it at login so your screen is one click away in the menu bar."
        alert.addButton(withTitle: "Launch at Login")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn { LaunchAtLogin.set(true) }
    }

    static func rename(_ current: String) -> String? {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Rename Virtual Screen"
        let field = NSTextField(string: current)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
    }

    struct CustomSize {
        let name: String
        let width: Int
        let height: Int
    }

    static func customSize() -> CustomSize? {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Custom Virtual Screen"
        alert.informativeText = "Enter the native pixel size of the screen you'll view it on. Radish offers sharp HiDPI sizes from there."
        let name = NSTextField(string: "Custom Screen")
        let width = NSTextField(string: "2560")
        let height = NSTextField(string: "1600")
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Name"), name],
            [NSTextField(labelWithString: "Width"), width],
            [NSTextField(labelWithString: "Height"), height],
        ])
        grid.column(at: 1).width = 180
        grid.rowSpacing = 8
        grid.frame = NSRect(x: 0, y: 0, width: 250, height: 88)
        alert.accessoryView = grid
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = width
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        // Even sizes keep the HiDPI options whole numbers.
        func even(_ field: NSTextField) -> Int? {
            guard let value = Int(field.stringValue.trimmingCharacters(in: .whitespaces)),
                  (640...7680).contains(value) else { return nil }
            return value - value % 2
        }
        guard let w = even(width), let h = even(height) else {
            let error = NSAlert()
            error.messageText = "Width and height must be between 640 and 7680 pixels."
            error.runModal()
            return nil
        }
        let title = name.stringValue.trimmingCharacters(in: .whitespaces)
        return CustomSize(name: title.isEmpty ? "Custom \(w) × \(h)" : title, width: w, height: h)
    }
}
