import Foundation

/// A screen shape to create a virtual screen from. Sizes are native pixels, landscape.
struct ScreenPreset {
    enum Group { case iPad, other }

    let name: String
    let width: Int
    let height: Int
    let ppi: Double
    let group: Group
}

enum Presets {
    static let all: [ScreenPreset] = [
        .init(name: "iPad Pro 11\" (M4, M5)", width: 2420, height: 1668, ppi: 264, group: .iPad),
        .init(name: "iPad Pro 13\" (M4, M5)", width: 2752, height: 2064, ppi: 264, group: .iPad),
        .init(name: "iPad Air 11\" / iPad 11\"", width: 2360, height: 1640, ppi: 264, group: .iPad),
        .init(name: "iPad Air 13\" / iPad Pro 12.9\"", width: 2732, height: 2048, ppi: 264, group: .iPad),
        .init(name: "iPad mini (A17 Pro)", width: 2266, height: 1488, ppi: 326, group: .iPad),
        .init(name: "iPad Pro 11\" (2018 to 2022)", width: 2388, height: 1668, ppi: 264, group: .iPad),
        .init(name: "16:9 (3840 × 2160)", width: 3840, height: 2160, ppi: 163, group: .other),
        .init(name: "16:10 (2880 × 1800)", width: 2880, height: 1800, ppi: 220, group: .other),
        .init(name: "3:2 (2880 × 1920)", width: 2880, height: 1920, ppi: 220, group: .other),
        .init(name: "4:3 (2732 × 2048)", width: 2732, height: 2048, ppi: 220, group: .other),
    ]
}
