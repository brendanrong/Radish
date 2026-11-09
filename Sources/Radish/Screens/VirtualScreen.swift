import Foundation

/// A virtual screen the user created. Persisted in UserDefaults.
struct VirtualScreen: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    /// Native pixels in landscape. Portrait swaps them.
    var width: Int
    var height: Int
    var ppi: Double
    /// Stable serial so macOS keeps its arrangement and settings across launches.
    var serial = UInt32.random(in: 1...0x00FF_FFFF)
    var enabled = true
    var portrait = false
    var scaleIndex = 0
    var isMain = false
    /// Every other display shows this screen, so remote apps stream one iPad-shaped desktop.
    var mirrorsOthers = false
    /// When it's its own screen: which side of the main display it sits on.
    var position: Position = .right

    enum Position: String, Codable, CaseIterable {
        case left, right, above, below
        var label: String { rawValue.capitalized }
        var detail: String {
            switch self {
            case .left: return "Past the left edge of your other screens"
            case .right: return "Past the right edge of your other screens"
            case .above: return "Above your main display"
            case .below: return "Below your main display"
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, width, height, ppi, serial, enabled, portrait, scaleIndex, isMain, position
        case mirrorsOthers = "mirrorsBuiltIn"   // stored name from 0.1
    }

    init(name: String, width: Int, height: Int, ppi: Double) {
        self.name = name
        self.width = width
        self.height = height
        self.ppi = ppi
    }

    /// Fields added after 0.1 are optional, so screens saved by older versions still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        width = try c.decode(Int.self, forKey: .width)
        height = try c.decode(Int.self, forKey: .height)
        ppi = try c.decode(Double.self, forKey: .ppi)
        serial = try c.decode(UInt32.self, forKey: .serial)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        portrait = try c.decodeIfPresent(Bool.self, forKey: .portrait) ?? false
        scaleIndex = try c.decodeIfPresent(Int.self, forKey: .scaleIndex) ?? 0
        isMain = try c.decodeIfPresent(Bool.self, forKey: .isMain) ?? false
        mirrorsOthers = try c.decodeIfPresent(Bool.self, forKey: .mirrorsOthers) ?? false
        position = try c.decodeIfPresent(Position.self, forKey: .position) ?? .right
    }

    var pixelWidth: Int { portrait ? height : width }
    var pixelHeight: Int { portrait ? width : height }

    var options: [LooksLike] { LooksLike.options(pixelWidth: pixelWidth, pixelHeight: pixelHeight) }

    var selected: LooksLike {
        let all = options
        return all[min(max(scaleIndex, 0), all.count - 1)]
    }
}

/// One "looks like" size for a virtual screen, in points.
struct LooksLike: Equatable {
    let width: Int
    let height: Int
    let hiDPI: Bool

    var backingWidth: Int { hiDPI ? width * 2 : width }
    var backingHeight: Int { hiDPI ? height * 2 : height }
    var label: String { "\(width) × \(height)" }

    /// The sharpest option is half the native pixels at 2x, like iPadOS itself.
    /// Larger factors trade sharpness for space. The last option is 1x native.
    static let factors: [Double] = [1.0, 1.125, 1.25, 1.5]

    static func options(pixelWidth: Int, pixelHeight: Int) -> [LooksLike] {
        let baseW = Double(pixelWidth) / 2
        let baseH = Double(pixelHeight) / 2
        var out = factors.map {
            LooksLike(width: Int((baseW * $0).rounded()), height: Int((baseH * $0).rounded()), hiDPI: true)
        }
        out.append(LooksLike(width: pixelWidth, height: pixelHeight, hiDPI: false))
        return out
    }
}

enum ScreenStore {
    private static let key = "virtualScreens"

    static func load() -> [VirtualScreen] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([VirtualScreen].self, from: data)) ?? []
    }

    static func save(_ screens: [VirtualScreen]) {
        if let data = try? JSONEncoder().encode(screens) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
