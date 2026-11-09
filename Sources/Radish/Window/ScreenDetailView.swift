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
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Jump Desktop is using its own display").font(.headline)
                            Text("With no other screen on, Jump makes a display sized for your iPad, so Radish steps aside. This screen comes back by itself when Jump's display goes away.")
                                .foregroundStyle(.secondary)
                            if let jump = model.displays.first(where: { Displays.isRemoteDesktopDisplay($0.id) }) {
                                Button("Change Jump's text size") { model.selection = .display(jump.id) }
                                    .buttonStyle(.link).padding(.top, 2)
                            }
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
                Text("Default matches iPadOS exactly. More Space fits more on screen with smaller text.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!screen.enabled)

            Section("Arrangement") {
                Toggle("Portrait", isOn: binding(screen.portrait) { model.setPortrait(screen.id, $0) })
                Toggle(isOn: binding(screen.mirrorsOthers) { model.setMirror(screen.id, $0) }) {
                    Text("Mirror other displays")
                    Text("Your other screens show this one, so Jump and other remote apps stream a single desktop in this shape.")
                }
                .disabled(!screen.enabled)
                Toggle(isOn: binding(screen.isMain) { model.setMain(screen.id, $0) }) {
                    Text("Use as main display")
                    Text("Moves the menu bar and Dock here. Best for a headless Mac mini.")
                }
                .disabled(!screen.enabled || screen.mirrorsOthers)
            }

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
