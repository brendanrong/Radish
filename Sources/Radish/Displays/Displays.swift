import AppKit

/// Thin wrappers over the public CoreGraphics display configuration API.
enum Displays {
    static func online() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }

    static func builtInID() -> CGDirectDisplayID? {
        online().first { CGDisplayIsBuiltin($0) != 0 }
    }

    static func isRadish(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayVendorNumber(id) == VirtualScreenManager.vendorID
    }

    static func name(_ id: CGDirectDisplayID) -> String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let screen = NSScreen.screens.first(where: { ($0.deviceDescription[key] as? NSNumber)?.uint32Value == id }) {
            return screen.localizedName
        }
        return CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "Display \(id)"
    }

    /// Stable identity for a physical display across reconnects.
    static func key(_ id: CGDirectDisplayID) -> String {
        "\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))"
    }

    // MARK: Modes

    static func isHiDPI(_ mode: CGDisplayMode) -> Bool { mode.pixelWidth > mode.width }

    static func same(_ a: CGDisplayMode, _ b: CGDisplayMode) -> Bool {
        a.width == b.width && a.height == b.height && a.pixelWidth == b.pixelWidth && a.pixelHeight == b.pixelHeight
    }

    static func current(_ id: CGDirectDisplayID) -> CGDisplayMode? { CGDisplayCopyDisplayMode(id) }

    /// Every desktop-usable mode, including the HiDPI ones System Settings hides,
    /// one per size (highest refresh rate wins), largest first.
    static func modes(_ id: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        let all = (CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode]) ?? []
        var best: [String: CGDisplayMode] = [:]
        for mode in all where mode.isUsableForDesktopGUI() {
            let key = "\(mode.width)x\(mode.height)@\(mode.pixelWidth)"
            if let existing = best[key], existing.refreshRate >= mode.refreshRate { continue }
            best[key] = mode
        }
        return best.values.sorted {
            ($0.width, $0.pixelWidth) > ($1.width, $1.pixelWidth)
        }
    }

    static func findMode(_ id: CGDirectDisplayID, width: Int, height: Int, hiDPI: Bool) -> CGDisplayMode? {
        modes(id).first { $0.width == width && $0.height == height && isHiDPI($0) == hiDPI }
    }

    static func describeModes(_ id: CGDirectDisplayID) -> String {
        modes(id).map { "\($0.width)x\($0.height)\(isHiDPI($0) ? "@2x" : "")" }.joined(separator: ", ")
    }

    // MARK: Configuration

    @discardableResult
    static func apply(_ mode: CGDisplayMode, to id: CGDirectDisplayID) -> Bool {
        configure { CGConfigureDisplayWithDisplayMode($0, id, mode, nil) }
    }

    /// Makes `display` show the same picture as `master`.
    static func mirror(_ display: CGDirectDisplayID, of master: CGDirectDisplayID) {
        guard CGDisplayMirrorsDisplay(display) != master else { return }
        configure { CGConfigureDisplayMirrorOfDisplay($0, display, master) }
    }

    static func unmirror(_ display: CGDirectDisplayID) {
        guard CGDisplayMirrorsDisplay(display) != kCGNullDirectDisplay else { return }
        configure { CGConfigureDisplayMirrorOfDisplay($0, display, kCGNullDirectDisplay) }
    }

    /// Makes every other display (built-in, external, TV) show `master`, so there's one desktop.
    static func mirrorOthers(onto master: CGDirectDisplayID) {
        let others = online().filter { $0 != master && !isRadish($0) && CGDisplayMirrorsDisplay($0) != master }
        guard !others.isEmpty else { return }
        Log.write("mirroring \(others.map { name($0) }) onto \(master)")
        configure { config in
            for other in others { CGConfigureDisplayMirrorOfDisplay(config, other, master) }
        }
    }

    static func unmirrorAll(from master: CGDirectDisplayID) {
        let mirrors = online().filter { CGDisplayMirrorsDisplay($0) == master }
        guard !mirrors.isEmpty else { return }
        configure { config in
            for display in mirrors { CGConfigureDisplayMirrorOfDisplay(config, display, kCGNullDirectDisplay) }
        }
    }

    /// The main display is the one at origin (0, 0); shift everything else to match.
    static func makeMain(_ id: CGDirectDisplayID) {
        guard CGDisplayIsMain(id) == 0 else { return }
        let origin = CGDisplayBounds(id).origin
        configure { config in
            for other in online() where CGDisplayMirrorsDisplay(other) == kCGNullDirectDisplay {
                let bounds = CGDisplayBounds(other)
                CGConfigureDisplayOrigin(config, other, Int32(bounds.origin.x - origin.x), Int32(bounds.origin.y - origin.y))
            }
        }
    }

    @discardableResult
    private static func configure(_ body: (CGDisplayConfigRef?) -> Void) -> Bool {
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        body(config)
        let result = CGCompleteDisplayConfiguration(config, .permanently)
        if result != .success { Log.write("display configuration failed: \(result.rawValue)") }
        return result == .success
    }
}

/// Output for `Radish --list-displays`.
enum DisplayReport {
    static func printAll() {
        for id in Displays.online() {
            let mode = Displays.current(id)
            let now = mode.map { "\($0.width)x\($0.height) (\($0.pixelWidth)x\($0.pixelHeight) px)" } ?? "?"
            print("[\(id)] \(Displays.name(id)) vendor \(CGDisplayVendorNumber(id)) serial \(CGDisplaySerialNumber(id))"
                  + "\(Displays.isRadish(id) ? " RADISH" : "")\(CGDisplayIsMain(id) != 0 ? " MAIN" : "")"
                  + "\(CGDisplayMirrorsDisplay(id) != 0 ? " mirrors \(CGDisplayMirrorsDisplay(id))" : "")")
            print("    now: \(now)")
            print("    modes: \(Displays.describeModes(id))")
        }
    }
}
