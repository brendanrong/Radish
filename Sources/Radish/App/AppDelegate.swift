import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menu: MenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("launch \(Bundle.main.shortVersion)")
        VirtualScreenManager.shared.startAll()
        ModeMemory.shared.startObserving()
        ModeMemory.shared.scheduleRestore()
        menu = MenuController()
    }

    /// radish://on, radish://off and radish://toggle switch every virtual screen,
    /// so a Shortcut or script can bring the iPad screen up before connecting.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { URLCommands.handle(url) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        VirtualScreenManager.shared.stopAll()
    }
}

extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
