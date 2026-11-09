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
}

/// What the window shows. A thin, observable view over VirtualScreenManager and Displays.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var screens: [VirtualScreen] = []
    private(set) var displays: [DisplayInfo] = []
    private(set) var launchAtLogin = false
    var selection: SidebarItem? = .general
    var restoreResolutions = ModeMemory.shared.enabled {
        didSet { ModeMemory.shared.enabled = restoreResolutions }
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
        displays = Displays.online()
            .filter { !Displays.isRadish($0) && CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
            .map { id in
                DisplayInfo(id: id, name: Displays.name(id), isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                            isMain: CGDisplayIsMain(id) != 0, current: Displays.current(id).map(ModeInfo.init),
                            modes: Displays.modes(id).map(ModeInfo.init))
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
    func rename(_ id: UUID, _ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, screens.first(where: { $0.id == id })?.name != trimmed else { return }
        manager.rename(id, trimmed)
        refresh()
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
