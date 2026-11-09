import AppKit

/// The submenu for one virtual screen.
@MainActor
enum ScreenMenu {
    static func item(for screen: VirtualScreen, target: MenuController) -> NSMenuItem {
        let item = NSMenuItem(title: screen.name, action: nil, keyEquivalent: "")
        item.state = screen.enabled ? .on : .off
        let looks = screen.selected
        item.subtitle = !screen.enabled ? "Off"
            : VirtualScreenManager.shared.paused ? "Paused while Jump Desktop has its own display"
            : "Looks like \(looks.label)\(screen.mirrorsOthers ? ", mirrored" : "")"

        let sub = NSMenu()
        sub.autoenablesItems = false
        sub.addItem(row("Connected", on: screen.enabled, #selector(MenuController.toggleScreen(_:)), screen, target))

        sub.addItem(.sectionHeader(title: "Looks like"))
        let options = screen.options
        for (index, option) in options.enumerated() {
            let row = row(option.label, on: index == min(screen.scaleIndex, options.count - 1),
                          #selector(MenuController.pickScale(_:)), screen, target)
            row.tag = index
            if index == 0 { row.subtitle = "Sharpest, matches iPadOS" }
            if !option.hiDPI { row.subtitle = "1x, tiny text" }
            row.isEnabled = screen.enabled
            sub.addItem(row)
        }

        sub.addItem(.separator())
        sub.addItem(row("Portrait", on: screen.portrait, #selector(MenuController.togglePortrait(_:)), screen, target))
        let mirror = row("Mirror Other Displays", on: screen.mirrorsOthers,
                         #selector(MenuController.toggleMirror(_:)), screen, target)
        mirror.subtitle = "One desktop for Jump, shaped like this screen"
        mirror.isEnabled = screen.enabled
        sub.addItem(mirror)
        let main = row("Use as Main Display", on: screen.isMain, #selector(MenuController.toggleMain(_:)), screen, target)
        main.isEnabled = screen.enabled && !screen.mirrorsOthers
        sub.addItem(main)

        sub.addItem(.separator())
        sub.addItem(row("Rename…", on: false, #selector(MenuController.renameScreen(_:)), screen, target))
        sub.addItem(row("Remove", on: false, #selector(MenuController.removeScreen(_:)), screen, target))
        item.submenu = sub
        return item
    }

    private static func row(_ title: String, on: Bool, _ selector: Selector,
                            _ screen: VirtualScreen, _ target: MenuController) -> NSMenuItem {
        let item = Menus.toggle(title, on: on, selector, target: target)
        item.representedObject = screen.id
        return item
    }
}

/// The resolution submenu for one physical (or other app's virtual) display.
@MainActor
enum DisplayMenu {
    static func item(for id: CGDirectDisplayID, target: MenuController) -> NSMenuItem {
        let item = NSMenuItem(title: Displays.name(id), action: nil, keyEquivalent: "")
        let current = Displays.current(id)
        if let current {
            item.subtitle = "\(current.width) × \(current.height)\(Displays.isHiDPI(current) ? ", HiDPI" : "")"
        }

        let sub = NSMenu()
        sub.autoenablesItems = false
        let modes = Displays.modes(id)
        let groups: [(String, [CGDisplayMode])] = [
            ("HiDPI", modes.filter(Displays.isHiDPI)),
            ("Standard", modes.filter { !Displays.isHiDPI($0) }),
        ]
        for (title, list) in groups where !list.isEmpty {
            sub.addItem(.sectionHeader(title: title))
            for mode in list {
                let row = Menus.toggle("\(mode.width) × \(mode.height)",
                                       on: current.map { Displays.same($0, mode) } ?? false,
                                       #selector(MenuController.pickMode(_:)), target: target)
                row.representedObject = mode
                row.tag = Int(id)
                sub.addItem(row)
            }
        }
        if modes.isEmpty { sub.addItem(Menus.note("No modes reported")) }
        item.submenu = sub
        return item
    }
}
