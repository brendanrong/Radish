import SwiftUI

/// A small diagram of the main display with the virtual screen beside it, to scale-ish.
struct ArrangementPreview: View {
    let screen: VirtualScreen

    var body: some View {
        GeometryReader { geo in
            let main = CGSize(width: 16, height: 9)
            let ipad = CGSize(width: CGFloat(screen.pixelWidth) / CGFloat(screen.pixelHeight) * 7, height: 7)
            let horizontal = screen.position == .left || screen.position == .right
            let total = horizontal
                ? CGSize(width: main.width + ipad.width + 1, height: max(main.height, ipad.height))
                : CGSize(width: max(main.width, ipad.width), height: main.height + ipad.height + 1)
            let k = min(geo.size.width / total.width, geo.size.height / total.height)
            let m = CGSize(width: main.width * k, height: main.height * k)
            let p = CGSize(width: ipad.width * k, height: ipad.height * k)
            let gap = k
            let (mainOrigin, ipadOrigin): (CGPoint, CGPoint) = {
                switch screen.position {
                case .right: return (.zero, CGPoint(x: m.width + gap, y: 0))
                case .left: return (CGPoint(x: p.width + gap, y: 0), .zero)
                case .above: return (CGPoint(x: max(0, (p.width - m.width) / 2), y: p.height + gap),
                                     CGPoint(x: max(0, (m.width - p.width) / 2), y: 0))
                case .below: return (CGPoint(x: max(0, (p.width - m.width) / 2), y: 0),
                                     CGPoint(x: max(0, (m.width - p.width) / 2), y: m.height + gap))
                }
            }()
            let used = CGSize(width: total.width * k, height: total.height * k)
            ZStack(alignment: .topLeading) {
                box(m, fill: Color.secondary.opacity(0.25), label: "Main")
                    .offset(x: mainOrigin.x, y: mainOrigin.y)
                box(p, fill: Brand.accent.opacity(0.75), label: "iPad", light: true)
                    .offset(x: ipadOrigin.x, y: ipadOrigin.y)
            }
            .frame(width: used.width, height: used.height, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }

    private func box(_ size: CGSize, fill: Color, label: String, light: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.secondary.opacity(0.4)))
            .overlay(Text(label).font(.caption2.weight(.semibold)).foregroundStyle(light ? .white : .secondary))
            .frame(width: size.width, height: size.height)
    }
}
