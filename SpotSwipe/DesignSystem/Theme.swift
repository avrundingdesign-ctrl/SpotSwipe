import SwiftUI
import UIKit

/// Farben und Maße aus dem Design (claude.ai Design-Fläche „SpotSwipe Design“).
enum Theme {
    static let background = Color(light: 0xF6F5F2, dark: 0x0E0E0F)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1B1B1D)
    static let textPrimary = Color(light: 0x121212, dark: 0xF3F2EF)
    static let textSecondary = Color(light: 0x66655F, dark: 0xA3A29C)
    static let hairline = Color(light: 0xE7E5DF, dark: 0x2C2C2F)
    static let fill = Color(light: 0xECEAE5, dark: 0x2A2A2E)
    static let inverseText = Color(light: 0xFEFEFE, dark: 0x0E0E0F)
    static let success = Color(light: 0x1F7A45, dark: 0x4CC37E)
    static let destructive = Color(light: 0xC2361B, dark: 0xFF7A5C)
    static let accent = Color(hex: 0xFF5533)
    static let star = Color(hex: 0xFFC940)

    static let cardRadius: CGFloat = 32
    static let sectionRadius: CGFloat = 22

    /// Platzhalter-Verläufe, solange ein Foto lädt oder fehlt.
    static let photoPalettes: [(Color, Color)] = [
        (Color(hex: 0xDCC7A9), Color(hex: 0x6B5440)),
        (Color(hex: 0xC9D6CF), Color(hex: 0x4F6458)),
        (Color(hex: 0xE7C9B8), Color(hex: 0x9A5B45)),
        (Color(hex: 0xCDD3E0), Color(hex: 0x55607A)),
        (Color(hex: 0xE5D5BC), Color(hex: 0x8C7350)),
        (Color(hex: 0xB9B3CF), Color(hex: 0x3F3A5A))
    ]

    static func photoPalette(for seed: String) -> (Color, Color) {
        let hash = seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return photoPalettes[hash % photoPalettes.count]
    }
}

// `nonisolated`: SwiftUI löst dynamische Farben auch auf seinem Render-Thread auf
// (etwa während Animationen). Ein an den MainActor gebundener Provider stürzt dort ab.
nonisolated extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
