import SwiftUI

struct GeneralView: View {
    @Bindable var model = AppModel.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Radish").font(.title2.weight(.semibold))
                        Text("Virtual screens shaped like your iPad.").foregroundStyle(.secondary)
                        Text("Version \(Bundle.main.shortVersion)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                    Text("Launch at login")
                    Text("Virtual screens only exist while Radish is running.")
                }
                Toggle(isOn: $model.connectOnLaunch) {
                    Text("Connect screens when Radish opens")
                    Text("Off keeps your Mac's screens as they are at startup. Turn a screen on when your iPad is ready.")
                }
                Toggle(isOn: $model.restoreResolutions) {
                    Text("Restore resolutions on reconnect")
                    Text("Puts back the size you picked when a display reconnects or your Mac wakes.")
                }
            }

            Section("Shortcuts and scripts") {
                LabeledContent("radish://on", value: "Connect every virtual screen")
                LabeledContent("radish://off", value: "Disconnect them")
                LabeledContent("radish://toggle", value: "Flip between the two")
                LabeledContent("radish://open", value: "Open this window")
            }

            Section {
                Link("Website", destination: URL(string: "https://brendanrong.github.io/Radish/")!)
                Button("Show Log in Finder") {
                    let log = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Radish.log")
                    NSWorkspace.shared.activateFileViewerSelecting([log])
                }
                .buttonStyle(.link)
            }
        }
        .formStyle(.grouped)
    }
}
