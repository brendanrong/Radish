import AppKit
import SwiftUI

enum Brand {
    /// Radish red. Matches the icon and the website (#C8174A light, #F0597E dark).
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.941, green: 0.349, blue: 0.494, alpha: 1)
            : NSColor(srgbRed: 0.784, green: 0.090, blue: 0.290, alpha: 1)
    })
}

/// A selectable tile for a resolution or "looks like" size.
struct OptionCard: View {
    let title: String
    var subtitle: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(selected ? Brand.accent : .secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 34 : 46)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Brand.accent.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(selected ? Brand.accent : Color(nsColor: .separatorColor), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A to-scale picture of a screen's shape, like a tablet seen from the front.
struct ScreenShape: View {
    let width: Int
    let height: Int
    let label: String
    let active: Bool

    var body: some View {
        GeometryReader { geo in
            let aspect = CGFloat(width) / CGFloat(max(height, 1))
            let fit = min(geo.size.width / aspect, geo.size.height)
            let size = CGSize(width: fit * aspect, height: fit)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(white: 0.5).opacity(0.35), lineWidth: 1))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active
                          ? LinearGradient(colors: [Brand.accent.opacity(0.85), Brand.accent.opacity(0.55)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.35)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(6)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: size.width, height: size.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A grid of option cards, sized for the detail pane.
struct CardGrid<Content: View>: View {
    var minimum: CGFloat = 130
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum), spacing: 8)], spacing: 8) {
            content
        }
        .padding(.vertical, 4)
    }
}
