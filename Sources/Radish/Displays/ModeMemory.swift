import AppKit

/// Remembers the resolution picked in Radish for each display and puts it back
/// when that display reconnects or the Mac wakes. This is the fix for remote
/// desktop sessions coming back with everything tiny.
@MainActor
final class ModeMemory {
    static let shared = ModeMemory()

    private struct Saved: Codable {
        let width: Int
        let height: Int
        let pixelWidth: Int
    }

    private let savedKey = "rememberedModes"
    private let enabledKey = "restoreResolutions"
    private var saved: [String: Saved] = [:]
    private var pending: DispatchWorkItem?

    init() {
        UserDefaults.standard.register(defaults: [enabledKey: true])
        if let data = UserDefaults.standard.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([String: Saved].self, from: data) {
            saved = decoded
        }
    }

    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    func remember(_ mode: CGDisplayMode, for id: CGDirectDisplayID) {
        saved[Displays.key(id)] = Saved(width: mode.width, height: mode.height, pixelWidth: mode.pixelWidth)
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: savedKey)
        }
    }

    func startObserving() {
        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            guard !flags.contains(.beginConfigurationFlag),
                  flags.contains(.addFlag) || flags.contains(.enabledFlag) else { return }
            DispatchQueue.main.async { ModeMemory.shared.scheduleRestore() }
        }, nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { ModeMemory.shared.scheduleRestore() }
        }
    }

    /// Waits for display changes to settle before touching anything.
    func scheduleRestore() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                VirtualScreenManager.shared.reapplyModes()
                self?.restoreAll()
            }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    private func restoreAll() {
        guard enabled else { return }
        for id in Displays.online() where !Displays.isRadish(id) {
            guard let want = saved[Displays.key(id)], let current = Displays.current(id) else { continue }
            if current.width == want.width, current.height == want.height, current.pixelWidth == want.pixelWidth { continue }
            guard let mode = Displays.modes(id).first(where: {
                $0.width == want.width && $0.height == want.height && $0.pixelWidth == want.pixelWidth
            }) else { continue }
            Log.write("restoring \(Displays.name(id)) to \(want.width)x\(want.height)")
            Displays.apply(mode, to: id)
        }
    }
}
