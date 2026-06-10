import SwiftUI
import Combine

class NewCassetteData: ObservableObject {
    @Published var selectedPhotos: [BCutPhoto] = []
    @Published var name: String = ""
    @Published var keywords: [String] = []
    @Published var design: CassetteDesign = .d1
    @Published var shouldDismiss: Bool = false
    var expiresAt: Date = Date().addingTimeInterval(86400 * 30)  // 30일 후
    let cassetteID: UUID = UUID()  // 로컬 파일 저장 경로용 고정 ID

    func buildCassette() -> CassetteModel {
        CassetteModel(
            id: cassetteID,
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
