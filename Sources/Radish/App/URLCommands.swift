import Foundation

@MainActor
enum URLCommands {
    static func handle(_ url: URL) {
        guard url.scheme == "radish" else { return }
        let manager = VirtualScreenManager.shared
        switch url.host?.lowercased() {
        case "on": manager.setAllEnabled(true)
        case "off": manager.setAllEnabled(false)
        case "toggle": manager.setAllEnabled(!manager.anyEnabled)
        default: Log.write("unknown url \(url.absoluteString)")
        }
    }
}
