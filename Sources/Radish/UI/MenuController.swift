import AppKit

/// The menu bar item. The menu is rebuilt every time it opens so the display list is live.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let screens = VirtualScreenManager.shared

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.toolTip = "Radish"
        screens.onChange = { [weak self] in self?.updateIcon() }
        updateIcon()
    }

    private func updateIcon() {
        item.button?.image = MenuBarIcon.image(filled: screens.anyEnabled)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(.sectionHeader(title: "Virtual Screens"))
        if screens.screens.isEmpty {
            menu.addItem(Menus.note("Add one shaped like your iPad below"))
        }
        for screen in screens.screens {
            menu.addItem(ScreenMenu.item(for: screen, target: self))
        }
        menu.addItem(newScreenItem())

        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Displays"))
        for id in Displays.online() where !Displays.isRadish(id) && CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay {
            menu.addItem(DisplayMenu.item(for: id, target: self))
        }

        menu.addItem(.separator())
        menu.addItem(Menus.toggle("Restore Resolutions on Reconnect", on: ModeMemory.shared.enabled,
                                  #selector(toggleRestore), target: self))
        menu.addItem(Menus.toggle("Launch at Login", on: LaunchAtLogin.isEnabled, #selector(toggleLogin), target: self))
        menu.addItem(.separator())
        menu.addItem(Menus.action("About Radish", #selector(about), target: self))
        menu.addItem(Menus.action("Quit Radish", #selector(quit), target: self, key: "q"))
    }

    private func newScreenItem() -> NSMenuItem {
        let item = NSMenuItem(title: "New Virtual Screen", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        sub.addItem(.sectionHeader(title: "iPad"))
        for (index, preset) in Presets.all.enumerated() where preset.group == .iPad {
            sub.addItem(presetItem(preset, index))
        }
        sub.addItem(.sectionHeader(title: "Other"))
        for (index, preset) in Presets.all.enumerated() where preset.group == .other {
            sub.addItem(presetItem(preset, index))
        }
        sub.addItem(.separator())
        sub.addItem(Menus.action("Custom Size…", #selector(addCustom), target: self))
        item.submenu = sub
        return item
    }

    private func presetItem(_ preset: ScreenPreset, _ index: Int) -> NSMenuItem {
        let item = Menus.action(preset.name, #selector(addPreset(_:)), target: self)
        item.tag = index
        if preset.group == .iPad { item.subtitle = "\(preset.width) × \(preset.height)" }
        return item
    }

    // MARK: Actions

    @objc private func addPreset(_ sender: NSMenuItem) {
        let preset = Presets.all[sender.tag]
        screens.add(name: preset.name, width: preset.width, height: preset.height, ppi: preset.ppi)
        Dialogs.offerLaunchAtLogin()
    }

    @objc private func addCustom() {
        guard let size = Dialogs.customSize() else { return }
        screens.add(name: size.name, width: size.width, height: size.height, ppi: 220)
        Dialogs.offerLaunchAtLogin()
    }

    @objc func toggleScreen(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        screens.setEnabled(id, sender.state != .on)
    }

    @objc func pickScale(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        screens.setScale(id, sender.tag)
    }

    @objc func togglePortrait(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        screens.setPortrait(id, sender.state != .on)
    }

    @objc func toggleMain(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        screens.setMain(id, sender.state != .on)
    }

    @objc func toggleMirror(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        screens.setMirror(id, sender.state != .on)
    }

    @objc func renameScreen(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let screen = screens.screens.first(where: { $0.id == id }),
              let name = Dialogs.rename(screen.name) else { return }
        screens.rename(id, name)
    }

    @objc func removeScreen(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        screens.remove(id)
    }

    @objc func pickMode(_ sender: NSMenuItem) {
        guard let object = sender.representedObject else { return }
        let mode = object as! CGDisplayMode
        let id = CGDirectDisplayID(sender.tag)
        if Displays.apply(mode, to: id) { ModeMemory.shared.remember(mode, for: id) }
    }

    @objc private func toggleRestore(_ sender: NSMenuItem) {
        ModeMemory.shared.enabled = sender.state != .on
    }

    @objc private func toggleLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.set(sender.state != .on)
    }

    @objc private func about() {
        NSApp.activate()
        let credits = NSMutableAttributedString(string: "Virtual screens and HiDPI for your Mac.\n")
        credits.append(NSAttributedString(string: "brendanrong.github.io/Radish",
                                          attributes: [.link: URL(string: "https://brendanrong.github.io/Radish/")!]))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

/// Small NSMenuItem builders.
@MainActor
enum Menus {
    static func action(_ title: String, _ selector: Selector, target: AnyObject, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = target
        return item
    }

    static func toggle(_ title: String, on: Bool, _ selector: Selector, target: AnyObject) -> NSMenuItem {
        let item = action(title, selector, target: target)
        item.state = on ? .on : .off
        return item
    }

    static func note(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
