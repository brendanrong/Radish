import AppKit
import Observation

extension Notification.Name {
    /// Posted when virtual screens or the display setup change, so every view can refresh.
    static let radishChanged = Notification.Name("RadishChanged")
}

enum SidebarItem: Hashable {
    case general
    case screen(UUID)
    case display(CGDirectDisplayID)
}

struct ModeInfo: Identifiable, Hashable {
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int

    init(_ mode: CGDisplayMode) {
        width = mode.width
        height = mode.height
        pixelWidth = mode.pixelWidth
        pixelHeight = mode.pixelHeight
    }

    var hiDPI: Bool { pixelWidth > width }
    var id: String { "\(width)x\(height)@\(pixelWidth)" }
    var label: String { "\(width) × \(height)" }
}

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let isBuiltIn: Bool
    let isMain: Bool
    let current: ModeInfo?
    let modes: [ModeInfo]
    /// The macOS default "looks like" size, when the display reports one.
    let defaultMode: ModeInfo?
    /// Set when this display is showing a Radish screen.
    let mirrorOf: CGDirectDisplayID?
    let mirrorName: String?

    /// Up to five sizes from Larger Text to More Space, the way System Settings offers them.
    var scaleChoices: [ModeInfo] {
        // Native = the biggest 1x mode. 2x modes report doubled pixels and can exceed the panel.
        let largest: (ModeInfo, ModeInfo) -> Bool = { $0.pixelWidth * $0.pixelHeight < $1.pixelWidth * $1.pixelHeight }
        let native = modes.filter { !$0.hiDPI }.max(by: largest) ?? modes.max(by: largest)
        let hi = modes.filter(\.hiDPI)
        var pool = hi.isEmpty ? modes : hi
        if let native {
            let aspect = Double(native.pixelWidth) / Double(native.pixelHeight)
            let sameShape = pool.filter { abs(Double($0.width) / Double($0.height) - aspect) < 0.02 }
            if sameShape.count >= 2 { pool = sameShape }
            // Skip sizes nobody picks: huge text at the bottom, unreadable text at the top.
            let low = hi.isEmpty ? native.pixelWidth / 2 : native.pixelWidth / 3
            let high = hi.isEmpty ? native.pixelWidth : native.pixelWidth * 4 / 5
            let sensible = pool.filter { (low...high).contains($0.width) }
            if sensible.count >= 2 { pool = sensible }
        }
        pool.sort { $0.width < $1.width }
        var picks = pool
        if pool.count > 5 {
            picks = (0..<5).map { pool[Int((Double($0) * Double(pool.count - 1) / 4).rounded())] }
        }
        // Always show the default and whatever is in use, replacing the nearest pick.
        for must in [defaultMode, current].compactMap({ $0 }) where pool.contains(must) && !picks.contains(must) {
            if let nearest = picks.indices.min(by: { abs(picks[$0].width - must.width) < abs(picks[$1].width - must.width) }) {
                picks[nearest] = must
            }
        }
        return picks.sorted { $0.width < $1.width }
    }
}

/// What the window shows. A thin, observable view over VirtualScreenManager and Displays.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var screens: [VirtualScreen] = []
    private(set) var displays: [DisplayInfo] = []
    private(set) var launchAtLogin = false
    /// Virtual screens are stepping aside for Jump Desktop's own display.
    private(set) var paused = false
    var selection: SidebarItem? = .general
    var restoreResolutions = ModeMemory.shared.enabled {
        didSet { ModeMemory.shared.enabled = restoreResolutions }
    }
    var connectOnLaunch = UserDefaults.standard.bool(forKey: "connectOnLaunch") {
        didSet { UserDefaults.standard.set(connectOnLaunch, forKey: "connectOnLaunch") }
    }

    @ObservationIgnored private var pending: DispatchWorkItem?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private let manager = VirtualScreenManager.shared

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(forName: .radishChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppModel.shared.scheduleRefresh() }
        }
    }

    func scheduleRefresh() {
        pending?.cancel()
        let work = DispatchWorkItem { MainActor.assumeIsolated { AppModel.shared.refresh() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func refresh() {
        screens = manager.screens
        paused = manager.paused
        displays = Displays.online()
            .filter { !Displays.isRadish($0) }
            .map { id in
                let master = CGDisplayMirrorsDisplay(id)
                let mirrorOf = master == kCGNullDirectDisplay ? nil : master
                let modes = Displays.modes(id)
                return DisplayInfo(
                    id: id, name: Displays.name(id), isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                    isMain: CGDisplayIsMain(id) != 0, current: Displays.current(id).map(ModeInfo.init),
                    modes: modes.map(ModeInfo.init),
                    defaultMode: modes.first { $0.ioFlags & 0x4 != 0 }.map(ModeInfo.init),   // kDisplayModeDefaultFlag
                    mirrorOf: mirrorOf,
                    mirrorName: mirrorOf.flatMap { m in screens.first { manager.displayID(for: $0.id) == m }?.name }
                )
            }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: Actions

    func addScreen(name: String, width: Int, height: Int, ppi: Double) {
        let screen = manager.add(name: name, width: width, height: height, ppi: ppi)
        refresh()
        selection = .screen(screen.id)
        Dialogs.offerLaunchAtLogin()
        refresh()
    }

    func removeScreen(_ id: UUID) {
        manager.remove(id)
        selection = .general
        refresh()
    }

    func setEnabled(_ id: UUID, _ on: Bool) { manager.setEnabled(id, on); refresh() }
    func setScale(_ id: UUID, _ index: Int) { manager.setScale(id, index); refresh() }
    func setPortrait(_ id: UUID, _ on: Bool) { manager.setPortrait(id, on); refresh() }
    func setMirror(_ id: UUID, _ on: Bool) { manager.setMirror(id, on); refresh() }
    func setMain(_ id: UUID, _ on: Bool) { manager.setMain(id, on); refresh() }
    func setPosition(_ id: UUID, _ position: VirtualScreen.Position) { manager.setPosition(id, position); refresh() }
    func rename(_ id: UUID, _ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, screens.first(where: { $0.id == id })?.name != trimmed else { return }
        manager.rename(id, trimmed)
        refresh()
    }

    /// Stops whichever Radish screen this display is mirroring.
    func stopMirroring(_ display: DisplayInfo) {
        guard let master = display.mirrorOf,
              let screen = screens.first(where: { manager.displayID(for: $0.id) == master }) else { return }
        setMirror(screen.id, false)
    }

    func apply(_ mode: ModeInfo, to id: CGDirectDisplayID) {
        guard let match = Displays.modes(id).first(where: { ModeInfo($0) == mode }) else { return }
        if Displays.apply(match, to: id) { ModeMemory.shared.remember(match, for: id) }
        scheduleRefresh()
    }

    func setLaunchAtLogin(_ on: Bool) {
        LaunchAtLogin.set(on)
        launchAtLogin = LaunchAtLogin.isEnabled
    }
}
