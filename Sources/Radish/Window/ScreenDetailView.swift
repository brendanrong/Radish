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
                        Text(screen.enabled ? "Connected" : "Off")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(screen.enabled ? Brand.accent : .secondary)
                    }
                    Spacer()
                    Toggle("Connected", isOn: binding(screen.enabled) { model.setEnabled(screen.id, $0) })
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.large)
                }
                .padding(.vertical, 6)
            }

            Section {
                CardGrid {
                    ForEach(Array(screen.options.enumerated()), id: \.offset) { index, option in
                        OptionCard(title: option.label, subtitle: subtitle(index, option),
                                   selected: index == selectedIndex) {
                            model.setScale(screen.id, index)
                        }
                    }
                }
                .disabled(!screen.enabled)
            } header: {
                Text("Looks like")
            } footer: {
                Text("Sharpest draws at 2x, exactly like iPadOS. Bigger sizes fit more on screen.")
                    .foregroundStyle(.secondary)
            }

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

    private func subtitle(_ index: Int, _ option: LooksLike) -> String? {
        if index == 0 { return "Sharpest" }
        if !option.hiDPI { return "1x, tiny text" }
        return nil
    }

    private func binding(_ value: Bool, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { value }, set: set)
    }
}
