import SwiftUI
import AppKit

// Color tokens and font helpers for the CertifsWatch design system.
// Colors adapt to light/dark via a dynamic NSColor provider.

extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}

enum Theme {
    // Surfaces
    static let bg         = Color(light: Color(red: 0.988, green: 0.988, blue: 0.992),
                                  dark:  Color(red: 0.114, green: 0.118, blue: 0.137))
    static let bgElev     = Color(light: Color.white,
                                  dark:  Color(red: 0.153, green: 0.157, blue: 0.180))
    static let bgSoft     = Color(light: Color(red: 0.957, green: 0.957, blue: 0.965),
                                  dark:  Color(red: 0.165, green: 0.169, blue: 0.196))
    static let bgHover    = Color(light: Color(red: 0.922, green: 0.925, blue: 0.933),
                                  dark:  Color(red: 0.204, green: 0.208, blue: 0.235))
    static let bgSel      = Color(light: Color(red: 0.882, green: 0.898, blue: 0.937),
                                  dark:  Color(red: 0.239, green: 0.263, blue: 0.314))
    static let scrim      = Color(light: Color(red: 0.941, green: 0.941, blue: 0.961).opacity(0.55),
                                  dark:  Color(red: 0.086, green: 0.094, blue: 0.110).opacity(0.60))

    // Text
    static let text       = Color(light: Color(red: 0.173, green: 0.180, blue: 0.200),
                                  dark:  Color(red: 0.941, green: 0.945, blue: 0.961))
    static let textSec    = Color(light: Color(red: 0.420, green: 0.424, blue: 0.439),
                                  dark:  Color(red: 0.722, green: 0.729, blue: 0.761))
    static let textTert   = Color(light: Color(red: 0.565, green: 0.569, blue: 0.584),
                                  dark:  Color(red: 0.537, green: 0.545, blue: 0.576))
    static let textQuat   = Color(light: Color(red: 0.682, green: 0.686, blue: 0.702),
                                  dark:  Color(red: 0.400, green: 0.408, blue: 0.435))

    // Lines
    static let line       = Color(light: Color.black.opacity(0.07),
                                  dark:  Color.white.opacity(0.08))
    static let lineStrong = Color(light: Color.black.opacity(0.12),
                                  dark:  Color.white.opacity(0.14))

    // Accent (blue)
    static let accent     = Color(light: Color(red: 0.243, green: 0.435, blue: 0.953),
                                  dark:  Color(red: 0.451, green: 0.627, blue: 0.988))
    static let accentBg   = Color(light: Color(red: 0.914, green: 0.937, blue: 0.996),
                                  dark:  Color(red: 0.176, green: 0.224, blue: 0.365))
    static let accentWeak = Color(light: Color(red: 0.878, green: 0.914, blue: 0.984),
                                  dark:  Color(red: 0.153, green: 0.184, blue: 0.298))

    // Status
    static let ok         = Color(light: Color(red: 0.149, green: 0.659, blue: 0.376),
                                  dark:  Color(red: 0.349, green: 0.816, blue: 0.541))
    static let okBg       = Color(light: Color(red: 0.886, green: 0.969, blue: 0.910),
                                  dark:  Color(red: 0.157, green: 0.286, blue: 0.200))
    static let warn       = Color(light: Color(red: 0.929, green: 0.667, blue: 0.118),
                                  dark:  Color(red: 0.945, green: 0.776, blue: 0.314))
    static let warnBg     = Color(light: Color(red: 0.996, green: 0.949, blue: 0.820),
                                  dark:  Color(red: 0.302, green: 0.239, blue: 0.137))
    static let crit       = Color(light: Color(red: 0.878, green: 0.259, blue: 0.196),
                                  dark:  Color(red: 0.910, green: 0.388, blue: 0.294))
    static let critBg     = Color(light: Color(red: 0.996, green: 0.898, blue: 0.878),
                                  dark:  Color(red: 0.314, green: 0.165, blue: 0.141))
    static let neu        = Color(light: Color(red: 0.467, green: 0.471, blue: 0.486),
                                  dark:  Color(red: 0.690, green: 0.694, blue: 0.710))
    static let neuBg      = Color(light: Color(red: 0.918, green: 0.918, blue: 0.925),
                                  dark:  Color(red: 0.255, green: 0.259, blue: 0.275))

    // Team swatches
    static let teamBlue   = Color(light: Color(red: 0.302, green: 0.463, blue: 0.933),
                                  dark:  Color(red: 0.478, green: 0.624, blue: 1.000))
    static let teamPurple = Color(light: Color(red: 0.502, green: 0.337, blue: 0.851),
                                  dark:  Color(red: 0.702, green: 0.533, blue: 0.933))
    static let teamGreen  = Color(light: Color(red: 0.176, green: 0.690, blue: 0.471),
                                  dark:  Color(red: 0.380, green: 0.800, blue: 0.580))
    static let teamOrange = Color(light: Color(red: 0.957, green: 0.580, blue: 0.212),
                                  dark:  Color(red: 1.000, green: 0.722, blue: 0.325))

    // Fonts
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }
}
