import SwiftUI

struct NewScreenSheet: View {
    let dismiss: () -> Void
    @State private var choice: Int? = 0          // index into Presets.all, nil = custom
    @State private var customName = "Custom Screen"
    @State private var customWidth = "2560"
    @State private var customHeight = "1600"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Virtual Screen").font(.title3.weight(.semibold)).padding([.horizontal, .top], 20)
            Text("Pick the screen you'll view it on. Radish matches its exact size.")
                .foregroundStyle(.secondary).padding(.horizontal, 20).padding(.top, 2)

            List(selection: $choice) {
                Section("iPad") { rows(.iPad) }
                Section("Other") { rows(.other) }
                Section("Custom") {
                    Label("Custom size", systemImage: "square.dashed").tag(Int?.none)
                }
            }
            .frame(minHeight: 300)
            .padding(.top, 10)

            if choice == nil {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow { Text("Name"); TextField("Name", text: $customName) }
                    GridRow {
                        Text("Size")
                        HStack {
                            TextField("Width", text: $customWidth).frame(width: 80)
                            Text("×")
                            TextField("Height", text: $customHeight).frame(width: 80)
                            Text("pixels").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12)
            }

            HStack {
                Spacer()
                Button("Cancel", action: dismiss).keyboardShortcut(.cancelAction)
                Button("Create", action: create).keyboardShortcut(.defaultAction).disabled(!valid)
            }
            .padding(20)
        }
        .frame(width: 440, height: 560)
        .tint(Brand.accent)
    }

    @ViewBuilder private func rows(_ group: ScreenPreset.Group) -> some View {
        ForEach(Array(Presets.all.enumerated()).filter { $0.element.group == group }, id: \.offset) { index, preset in
            HStack {
                Image(systemName: group == .iPad ? "ipad.landscape" : "display")
                Text(preset.name)
                Spacer()
                Text(verbatim: "\(preset.width) × \(preset.height)").monospacedDigit().foregroundStyle(.secondary)
            }
            .tag(Int?.some(index))
        }
    }

    private func size(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), (640...7680).contains(value) else { return nil }
        return value - value % 2   // even sizes keep the HiDPI options whole numbers
    }

    private var valid: Bool { choice != nil || (size(customWidth) != nil && size(customHeight) != nil) }

    private func create() {
        if let index = choice {
            let preset = Presets.all[index]
            dismiss()
            AppModel.shared.addScreen(name: preset.name, width: preset.width, height: preset.height, ppi: preset.ppi)
        } else if let w = size(customWidth), let h = size(customHeight) {
            let name = customName.trimmingCharacters(in: .whitespaces)
            dismiss()
            AppModel.shared.addScreen(name: name.isEmpty ? "Custom \(w) × \(h)" : name, width: w, height: h, ppi: 220)
        }
    }
}
