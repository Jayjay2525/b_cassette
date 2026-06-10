import SwiftUI

// MARK: - Colors
extension Color {
    static let appBackground = Color(hex: "#DDDDDD")  // lightgray
    static let appAccent     = Color(hex: "#FF2D2D")
    static let appWhite      = Color(hex: "#FFFFFF")  // white
    static let appBlack      = Color.black
    static let appGray       = Color(hex: "#B3B3B3")  // gray
    static let appDarkGray   = Color(hex: "#555555")  // darkgray
    static let appLightGray  = Color(hex: "#DDDDDD")  // lightgray (= appBackground)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography
extension Font {
    static func cutiveMono(_ size: CGFloat) -> Font {
        .custom("CutiveMono-Regular", size: size)
    }
}

// MARK: - Constants
enum AppConstants {
    static let maxCassettes = 10
    static let maxBCuts = 50
    static let canvasWidth: CGFloat = 393
    static let canvasHeight: CGFloat = 852
}
