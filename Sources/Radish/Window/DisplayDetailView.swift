import SwiftUI

struct DisplayDetailView: View {
    let display: DisplayInfo
    private var model: AppModel { .shared }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Brand.accent)
                        .frame(width: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.name).font(.title2.weight(.semibold))
                        if let current = display.current {
                            Text(verbatim: "Looks like \(current.label) · \(current.pixelWidth) × \(current.pixelHeight) pixels")
                                .foregroundStyle(.secondary)
                        }
                        if display.isMain {
                            Text("Main display").font(.callout.weight(.medium)).foregroundStyle(Brand.accent)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }

            if Displays.isRemoteDesktopDisplay(display.id) {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "ipad.landscape").font(.title2).foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Jump Desktop controls this display").font(.headline)
                            Text("It's already sized for your iPad, and Jump puts back its own size if anything else changes it. Use Change Resolution in Jump on your iPad instead.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if let mirrorName = display.mirrorName {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.title2).foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Showing \(mirrorName)").font(.headline)
                            Text("This display mirrors your virtual screen, so it follows that screen's size.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Stop Mirroring") { model.stopMirroring(display) }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    ScalePicker(options: scaleOptions, selected: display.current?.id) { id in
                        if let mode = display.modes.first(where: { $0.id == id }) { model.apply(mode, to: display.id) }
                    }
                    DisclosureGroup("All resolutions") {
                        modeGrid("Sharp (HiDPI)", modes: display.modes.filter(\.hiDPI))
                        modeGrid("Standard", modes: display.modes.filter { !$0.hiDPI })
                    }
                } header: {
                    Text("Text size")
                } footer: {
                    if model.restoreResolutions {
                        Text("Radish puts this size back whenever the display reconnects or your Mac wakes.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var scaleOptions: [ScaleOption] {
        let choices = display.scaleChoices
        let narrowest = choices.first?.width ?? 1
        return choices.enumerated().map { index, mode in
            let title: String? = mode == display.defaultMode ? "Default"
                : index == 0 ? "Larger Text"
                : index == choices.count - 1 ? "More Space" : nil
            return ScaleOption(id: mode.id, title: title, caption: mode.label,
                               textSize: ScalePicker.textSize(width: mode.width, narrowest: narrowest))
        }
    }

    @ViewBuilder
    private func modeGrid(_ title: String, modes: [ModeInfo]) -> some View {
        if !modes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 8)
                CardGrid(minimum: 118) {
                    ForEach(modes) { mode in
                        OptionCard(title: mode.label, selected: mode == display.current) {
                            model.apply(mode, to: display.id)
                        }
                    }
                }
            }
        }
    }
}
