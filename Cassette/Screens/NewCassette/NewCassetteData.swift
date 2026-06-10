import SwiftUI
import Combine

class NewCassetteData: ObservableObject {
    @Published var selectedPhotos: [BCutPhoto] = []
    @Published var name: String = ""
    @Published var keywords: [String] = []
    @Published var design: CassetteDesign = .nr
    @Published var shouldDismiss: Bool = false
    var expiresAt: Date = Date().addingTimeInterval(86400 * 30)  // 30일 후

    func buildCassette() -> CassetteModel {
        CassetteModel(
            id: UUID(),
            name: name.isEmpty ? "untitled" : name,
            createdAt: Date(),
            expiresAt: expiresAt,
            photos: selectedPhotos,
            keywords: keywords,
            design: design,
            printProgress: 1.0
        )
    }
}
