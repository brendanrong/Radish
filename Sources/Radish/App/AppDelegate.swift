import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menu: MenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("launch \(Bundle.main.shortVersion)")
        // Screens start off unless asked, so a Mac that boots without the iPad looks normal.
        if !UserDefaults.standard.bool(forKey: "connectOnLaunch") {
            VirtualScreenManager.shared.setAllEnabled(false)
        }
        VirtualScreenManager.shared.startAll()
        ModeMemory.shared.startObserving()
        ModeMemory.shared.scheduleRestore()
        MainMenu.install()
        menu = MenuController()
        // Open the window on the very first launch so people find their way in.
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            MainWindow.shared.show()
        }
    }

    /// Opening Radish from Finder, Spotlight or the Dock while it's running shows the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindow.shared.show()
        return true
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
