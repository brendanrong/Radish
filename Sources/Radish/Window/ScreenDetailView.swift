import SwiftUI

struct ScreenDetailView: View {
    let screen: VirtualScreen
    @State private var name = ""
    @State private var confirmingRemove = false
    private var model: AppModel { .shared }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 20) {
                    ScreenShape(width: screen.pixelWidth, height: screen.pixelHeight,
                                label: screen.selected.label, active: screen.enabled)
                        .frame(width: 150, height: 112)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Name", text: $name)
                            .labelsHidden()
                            .textFieldStyle(.plain)
                            .font(.title2.weight(.semibold))
                            .onSubmit { model.rename(screen.id, name) }
                        Text(verbatim: "\(screen.pixelWidth) × \(screen.pixelHeight) pixels · \(Int(screen.ppi)) ppi")
                            .foregroundStyle(.secondary)
                        Text(!screen.enabled ? "Off" : model.paused ? "Paused for Jump Desktop" : "Connected")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(screen.enabled && !model.paused ? Brand.accent : .secondary)
                    }
                    Spacer()
                    Toggle("Connected", isOn: binding(screen.enabled) { model.setEnabled(screen.id, $0) })
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.large)
                }
                .padding(.vertical, 6)
            }

            if model.paused && screen.enabled {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "pause.circle").font(.title2).foregroundStyle(Brand.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jump Desktop has taken over the screens").font(.headline)
                            Text("Jump switched off your Mac's screens for this session and is showing its own display, already sized for your iPad. Radish steps aside and comes back when the session ends.")
                                .foregroundStyle(.secondary)
                            Text("To change text size now, use Change Resolution in Jump on your iPad. To use One desktop or Its own screen during Jump sessions, turn off Lock Mac screen in Jump's privacy settings so your screens stay on.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                ScalePicker(options: scaleOptions, selected: String(selectedIndex)) {
                    model.setScale(screen.id, Int($0) ?? 0)
                }
                DisclosureGroup("All sizes") {
                    CardGrid {
                        ForEach(Array(screen.options.enumerated()), id: \.offset) { index, option in
                            OptionCard(title: option.label, subtitle: subtitle(index, option),
                                       selected: index == selectedIndex) {
                                model.setScale(screen.id, index)
                            }
                        }
                    }
                }
            } header: {
                Text("Text size")
            } footer: {
                Text(model.paused
                     ? "Picks apply when the screen comes back after your Jump session."
                     : "Default matches iPadOS exactly. More Space fits more on screen with smaller text.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!screen.enabled)

            Section {
                Picker("Show as", selection: Binding(get: { screen.mirrorsOthers },
                                                     set: { model.setMirror(screen.id, $0) })) {
                    Text("One desktop").tag(true)
                    Text("Its own screen").tag(false)
                }
                .pickerStyle(.segmented)

                if !screen.mirrorsOthers {
                    HStack(alignment: .center, spacing: 20) {
                        ArrangementPreview(screen: screen)
                            .frame(width: 170, height: 96)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Position").font(.callout.weight(.medium))
                            Picker("Position", selection: Binding(get: { screen.position },
                                                                  set: { model.setPosition(screen.id, $0) })) {
                                ForEach(VirtualScreen.Position.allCases, id: \.self) { side in
                                    Text(side.label).tag(side)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            Text(screen.position.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        .disabled(screen.isMain)
                    }
                    .padding(.vertical, 4)
                    Toggle(isOn: binding(screen.isMain) { model.setMain(screen.id, $0) }) {
                        Text("Use as main display")
                        Text("Moves the menu bar and Dock here. Best for a headless Mac mini.")
                    }
                }
                Toggle("Portrait", isOn: binding(screen.portrait) { model.setPortrait(screen.id, $0) })
            } header: {
                Text("Arrangement")
            } footer: {
                Text(screen.mirrorsOthers
                     ? "Every screen shows this one, so Jump streams a single desktop in its shape. Changing the size changes them all."
                     : "A separate desktop with its own size and windows; your other screens stay as they are. In Jump, switch to this monitor to see it.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!screen.enabled)

            Section {
                Button("Remove Screen…", role: .destructive) { confirmingRemove = true }
            }
        }
        .formStyle(.grouped)
        .onAppear { name = screen.name }
        .onChange(of: screen.id) { name = screen.name }
        .confirmationDialog("Remove \(screen.name)?", isPresented: $confirmingRemove) {
            Button("Remove", role: .destructive) { model.removeScreen(screen.id) }
        } message: {
            Text("The screen disconnects and its windows move to your other displays.")
        }
    }

    private var selectedIndex: Int { min(max(screen.scaleIndex, 0), screen.options.count - 1) }

    /// The sharp (2x) sizes as a Default to More Space row. The 1x size lives under All sizes.
    private var scaleOptions: [ScaleOption] {
        let sharp = screen.options.enumerated().filter { $0.element.hiDPI }
        let narrowest = sharp.first?.element.width ?? 1
        return sharp.map { index, option in
            ScaleOption(id: String(index),
                        title: index == 0 ? "Default" : (index == sharp.last?.offset ? "More Space" : nil),
                        caption: option.label,
                        textSize: ScalePicker.textSize(width: option.width, narrowest: narrowest))
        }
    }

    private func subtitle(_ index: Int, _ option: LooksLike) -> String? {
        if index == 0 { return "Sharpest" }
        if !option.hiDPI { return "1x, tiny text" }
        return nil
    }

    private func binding(_ value: Bool, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: set)
    }
}
