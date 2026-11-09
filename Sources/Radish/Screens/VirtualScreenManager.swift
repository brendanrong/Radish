import AppKit
import CVirtualDisplay

/// Owns the live CGVirtualDisplay objects. A virtual screen exists only while its
/// object is alive, so Radish has to keep running for the screen to stay connected.
@MainActor
final class VirtualScreenManager {
    static let shared = VirtualScreenManager()
    nonisolated static let vendorID: UInt32 = 0x5244   // "RD"
    nonisolated static let productID: UInt32 = 0x0D15

    private(set) var screens: [VirtualScreen] = ScreenStore.load()
    private var live: [UUID: CGVirtualDisplay] = [:]
    private var startedAt: [UUID: Date] = [:]
    private var pendingCheck: DispatchWorkItem?
    var onChange: (() -> Void)?

    /// True while Jump Desktop is showing its own display. Jump only makes one when the Mac
    /// has no screen of its own, and sizes it to the iPad, so Radish steps aside.
    private(set) var paused = false

    var anyEnabled: Bool { screens.contains { $0.enabled } }

    func displayID(for id: UUID) -> CGDirectDisplayID? { live[id]?.displayID }

    // MARK: Lifecycle

    func startAll() {
        guard !paused else { return }
        if Displays.online().contains(where: Displays.isRemoteDesktopDisplay) {
            paused = true
            Log.write("Jump Desktop has its own display, virtual screens wait")
            changed()
            return
        }
        for screen in screens where screen.enabled { start(screen) }
        changed()
        scheduleCheck()
    }

    /// Runs after any display change: pause for Jump, resume after it, and bring back
    /// a screen macOS dropped.
    func scheduleCheck() {
        pendingCheck?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { VirtualScreenManager.shared.check() } }
        pendingCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func check() {
        let online = Displays.online()
        let jump = online.contains(where: Displays.isRemoteDesktopDisplay)
        if jump && !paused {
            paused = true
            Log.write("Jump Desktop has its own display, pausing virtual screens")
            for id in Array(live.keys) { stop(id) }
            changed()
        } else if !jump && paused {
            paused = false
            Log.write("Jump Desktop display gone, resuming virtual screens")
            startAll()
        } else if !paused {
            for screen in screens where screen.enabled {
                guard let display = live[screen.id], !online.contains(display.displayID),
                      Date().timeIntervalSince(startedAt[screen.id] ?? .distantPast) > 4 else { continue }
                Log.write("\(screen.name) was dropped by macOS, bringing it back")
                live[screen.id] = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self, let fresh = self.screens.first(where: { $0.id == screen.id }), fresh.enabled else { return }
                    self.start(fresh)
                    self.changed()
                }
            }
        }
    }

    func stopAll() {
        for id in Array(live.keys) { stop(id) }
    }

    private func start(_ screen: VirtualScreen) {
        guard live[screen.id] == nil, !paused else { return }
        let options = screen.options
        // Modes are listed in points; with hiDPI on, macOS backs each at 2x as long
        // as that fits inside maxPixels.
        let backing = Array(Set(options.map { Size(w: $0.width, h: $0.height) }))
            .sorted { $0.w > $1.w }
        let maxW = options.map(\.backingWidth).max() ?? 0
        let maxH = options.map(\.backingHeight).max() ?? 0
        guard maxW > 0 else { return }
        let largest = Size(w: maxW, h: maxH)

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = screen.name
        descriptor.maxPixelsWide = UInt32(largest.w)
        descriptor.maxPixelsHigh = UInt32(largest.h)
        descriptor.sizeInMillimeters = CGSize(
            width: Double(screen.pixelWidth) / screen.ppi * 25.4,
            height: Double(screen.pixelHeight) / screen.ppi * 25.4
        )
        descriptor.vendorID = Self.vendorID
        descriptor.productID = Self.productID
        descriptor.serialNum = screen.serial
        descriptor.terminationHandler = { _, _ in
            Log.write("virtual screen \(screen.name) was terminated by the system")
        }

        guard let display = CGVirtualDisplay(descriptor: descriptor) else {
            Log.write("could not create virtual screen \(screen.name)")
            return
        }
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = backing.map { CGVirtualDisplayMode(width: UInt($0.w), height: UInt($0.h), refreshRate: 60) }
        guard display.apply(settings) else {
            Log.write("could not apply modes to \(screen.name)")
            return
        }
        live[screen.id] = display
        startedAt[screen.id] = Date()
        Log.write("started \(screen.name) id \(display.displayID) \(screen.pixelWidth)x\(screen.pixelHeight)")
        applyLayout(screen.id, attempt: 0)
    }

    private func stop(_ id: UUID) {
        guard let display = live[id] else { return }
        if let screen = screens.first(where: { $0.id == id }), screen.mirrorsOthers {
            Displays.unmirrorAll(from: display.displayID)
        }
        Log.write("stopped id \(display.displayID)")
        live[id] = nil
    }

    /// The display shows up a moment after creation, so retry until its modes exist.
    private func applyLayout(_ id: UUID, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let screen = self.screens.first(where: { $0.id == id }),
                  let displayID = self.live[id]?.displayID else { return }
            let want = screen.selected
            guard let mode = Displays.findMode(displayID, width: want.width, height: want.height, hiDPI: want.hiDPI) else {
                if attempt < 8 { self.applyLayout(id, attempt: attempt + 1) } else {
                    Log.write("no \(want.label) mode on \(screen.name); has \(Displays.describeModes(displayID))")
                }
                return
            }
            if Displays.current(displayID).map({ !Displays.same($0, mode) }) ?? true {
                Displays.apply(mode, to: displayID)
            }
            if screen.mirrorsOthers {
                Displays.mirrorOthers(onto: displayID)
            } else if screen.isMain {
                Displays.makeMain(displayID)
            }
            self.changed()
        }
    }

    /// Puts each live screen back on its chosen size, e.g. after sleep.
    func reapplyModes() {
        for screen in screens where live[screen.id] != nil {
            guard let displayID = live[screen.id]?.displayID else { continue }
            let want = screen.selected
            guard let mode = Displays.findMode(displayID, width: want.width, height: want.height, hiDPI: want.hiDPI),
                  let current = Displays.current(displayID), !Displays.same(current, mode) else { continue }
            Log.write("restoring \(screen.name) to \(want.label)")
            Displays.apply(mode, to: displayID)
        }
    }

    // MARK: Editing

    @discardableResult
    func add(name: String, width: Int, height: Int, ppi: Double) -> VirtualScreen {
        let screen = VirtualScreen(name: name, width: width, height: height, ppi: ppi)
        screens.append(screen)
        save()
        start(screen)
        changed()
        return screen
    }

    func remove(_ id: UUID) {
        stop(id)
        screens.removeAll { $0.id == id }
        save()
        changed()
    }

    func setEnabled(_ id: UUID, _ enabled: Bool) {
        mutate(id) { $0.enabled = enabled }
        guard let screen = screens.first(where: { $0.id == id }) else { return }
        enabled ? start(screen) : stop(id)
        changed()
    }

    func setAllEnabled(_ enabled: Bool) {
        for screen in screens { setEnabled(screen.id, enabled) }
    }

    func setScale(_ id: UUID, _ index: Int) {
        mutate(id) { $0.scaleIndex = index }
        applyLayout(id, attempt: 0)
    }

    func rename(_ id: UUID, _ name: String) {
        mutate(id) { $0.name = name }
        rebuild(id)
    }

    func setPortrait(_ id: UUID, _ portrait: Bool) {
        mutate(id) { $0.portrait = portrait }
        rebuild(id)
    }

    func setMain(_ id: UUID, _ main: Bool) {
        for screen in screens { mutate(screen.id) { $0.isMain = main && screen.id == id } }
        if main { applyLayout(id, attempt: 0) } else if let builtIn = Displays.builtInID() {
            Displays.makeMain(builtIn)
        }
    }

    func setMirror(_ id: UUID, _ mirror: Bool) {
        for screen in screens { mutate(screen.id) { $0.mirrorsOthers = mirror && screen.id == id } }
        if mirror {
            applyLayout(id, attempt: 0)
        } else if let displayID = displayID(for: id) {
            Displays.unmirrorAll(from: displayID)
        }
    }

    /// Mode lists and names are fixed at creation, so some edits recreate the display.
    private func rebuild(_ id: UUID) {
        guard let screen = screens.first(where: { $0.id == id }), screen.enabled else { return }
        stop(id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, let fresh = self.screens.first(where: { $0.id == id }), fresh.enabled else { return }
            self.start(fresh)
        }
    }

    private func mutate(_ id: UUID, _ change: (inout VirtualScreen) -> Void) {
        guard let index = screens.firstIndex(where: { $0.id == id }) else { return }
        change(&screens[index])
        save()
        changed()
    }

    private func save() { ScreenStore.save(screens) }

    private func changed() {
        onChange?()
        NotificationCenter.default.post(name: .radishChanged, object: nil)
    }
}

private struct Size: Hashable {
    let w: Int
    let h: Int
}
