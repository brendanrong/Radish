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

            modeSection("HiDPI", footer: "Sharp text at 2x. Includes sizes System Settings hides.",
                        modes: display.modes.filter(\.hiDPI))
            modeSection("Standard", footer: nil, modes: display.modes.filter { !$0.hiDPI })

            if model.restoreResolutions {
                Section {
                    Label("Radish puts back the size you pick here whenever this display reconnects or your Mac wakes.",
                          systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func modeSection(_ title: String, footer: String?, modes: [ModeInfo]) -> some View {
        if !modes.isEmpty {
            Section {
                CardGrid(minimum: 118) {
                    ForEach(modes) { mode in
                        OptionCard(title: mode.label, selected: mode == display.current) {
                            model.apply(mode, to: display.id)
                        }
                    }
                }
            } header: {
                Text(title)
            } footer: {
                if let footer { Text(footer).foregroundStyle(.secondary) }
            }
        }
    }
}
