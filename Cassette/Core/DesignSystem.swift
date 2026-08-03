import SwiftUI

// MARK: - Colors
extension Color {
    static let appLightGray   = Color(hex: "#DDDDDD")
    static let appWarnRed     = Color(hex: "#FF2D2D")
    static let appDarkRed     = Color(hex: "#3D1A1A")
    static let appWhite       = Color(hex: "#F7F7F7")
    static let appBlack       = Color(hex: "#111111")
    static let appGray        = Color(hex: "#AAAAAA")
    static let appDarkGray    = Color(hex: "#363636")
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

    // Named styles
    static let appHeader   = cutiveMono(24)  // 섹션 헤더 (온보딩 패널 제목)
    static let appTitle    = cutiveMono(20)  // 네비게이션 바, 이름 입력
    static let appBody     = cutiveMono(17)  // 본문, 키워드, 날짜, 버튼
    static let appMicro    = cutiveMono(15)  // 타임라벨, 카운터, 토스트, 작은 안내
}

// MARK: - Constants
enum AppConstants {
    static let maxCassettes = 10
    static let maxBCuts = 50
    static let canvasWidth: CGFloat = 393
    static let canvasHeight: CGFloat = 852
}
