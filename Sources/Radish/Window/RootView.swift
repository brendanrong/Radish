import SwiftUI

struct RootView: View {
    @Bindable var model = AppModel.shared
    @State private var showingNewScreen = false

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selection) {
                Label("General", systemImage: "gearshape").tag(SidebarItem.general)

                Section("Virtual Screens") {
                    ForEach(model.screens) { screen in
                        ScreenRow(screen: screen).tag(SidebarItem.screen(screen.id))
                    }
                    Button { showingNewScreen = true } label: {
                        Label("New Screen…", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Brand.accent)
                }

                Section("Displays") {
                    ForEach(model.displays) { display in
                        DisplayRow(display: display).tag(SidebarItem.display(display.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 300)
        } detail: {
            detail
        }
        .tint(Brand.accent)
        .sheet(isPresented: $showingNewScreen) {
            NewScreenSheet { showingNewScreen = false }
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.selection {
        case .screen(let id):
            if let screen = model.screens.first(where: { $0.id == id }) {
                ScreenDetailView(screen: screen)
            } else {
                GeneralView()
            }
        case .display(let id):
            if let display = model.displays.first(where: { $0.id == id }) {
                DisplayDetailView(display: display)
            } else {
                GeneralView()
            }
        default:
            GeneralView()
        }
    }
}

private struct ScreenRow: View {
    let screen: VirtualScreen

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(screen.name).lineLimit(1)
                Text(screen.enabled ? "Looks like \(screen.selected.label)" : "Off")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: screen.portrait ? "ipad" : "ipad.landscape")
                .foregroundStyle(screen.enabled ? Brand.accent : .secondary)
        }
    }
}

private struct DisplayRow: View {
    let display: DisplayInfo

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(display.name).lineLimit(1)
                Text(display.mirrorName.map { "Mirroring \($0)" }
                     ?? display.current.map { "\($0.label)\($0.hiDPI ? ", HiDPI" : "")" } ?? "")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        } icon: {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
        }
    }
}
