import SwiftUI

/// One choice in the "Larger Text ↔ More Space" row.
struct ScaleOption: Identifiable {
    let id: String
    let title: String?      // "Larger Text", "Default", "More Space", or nil
    let caption: String     // the resolution, e.g. "1210 × 834"
    let textSize: CGFloat   // how big text renders in the preview
}

/// The System Settings style size picker: little windows whose text shrinks as you
/// pick more space, with the actual resolution printed under each one.
struct ScalePicker: View {
    let options: [ScaleOption]
    let selected: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(options) { option in
                let isSelected = option.id == selected
                Button { onSelect(option.id) } label: {
                    VStack(spacing: 8) {
                        TextPreview(textSize: option.textSize, selected: isSelected)
                        VStack(spacing: 1) {
                            Text(option.title ?? " ")
                                .font(.callout.weight(isSelected ? .semibold : .regular))
                            Text(verbatim: option.caption)
                                .font(.caption).monospacedDigit()
                                .foregroundStyle(isSelected ? Brand.accent : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel([option.title, option.caption].compactMap { $0 }.joined(separator: ", "))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 10)
    }

    /// Text size for a "looks like" width: the narrowest option gets the biggest text.
    static func textSize(width: Int, narrowest: Int) -> CGFloat {
        max(5, 14 * CGFloat(narrowest) / CGFloat(max(width, 1)))
    }
}

/// A tiny window with traffic lights and a paragraph, drawn at a given text size.
private struct TextPreview: View {
    let textSize: CGFloat
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: textSize * 0.4) {
            HStack(spacing: textSize * 0.3) {
                dot(Color(red: 1.0, green: 0.37, blue: 0.34))
                dot(Color(red: 1.0, green: 0.74, blue: 0.18))
                dot(Color(red: 0.16, green: 0.78, blue: 0.25))
            }
            Text("Crisp, peppery and best served sharp. Every pixel lands right where your screen wants it.")
                .font(.system(size: textSize))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(7)
        .frame(width: 92, height: 72, alignment: .topLeading)
        .clipped()
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(nsColor: .separatorColor)))
        .padding(4)
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(selected ? Brand.accent : .clear, lineWidth: 3)
        )
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: textSize * 0.7, height: textSize * 0.7)
    }
}
