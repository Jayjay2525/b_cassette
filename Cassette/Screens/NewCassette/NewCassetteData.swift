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

    private static let trackList: [(name: String, ext: String)] = [
        ("sound_1", "mp3"), ("sound_2", "mp3"), ("sound_3", "mp3"),
        ("sound_4", "mp3"), ("sound_5", "mp3"), ("sound_6", "mp3"),
        ("sound_7", "mp3"), ("sound_8", "mp3"), ("sound_9", "mp3")
    ]

    static func randomTrackName() -> String {
        let track = trackList.randomElement()!
        return "\(track.name).\(track.ext)"
    }

    func buildCassette() -> CassetteModel {
        let track = Self.trackList.randomElement()!
        return CassetteModel(
            id: cassetteID,
            name: name.isEmpty ? "untitled" : name,
            createdAt: Date(),
            expiresAt: expiresAt,
            photos: selectedPhotos,
            keywords: keywords,
            design: design,
            printProgress: 1.0,
            trackName: "\(track.name).\(track.ext)"
        )
    }
}
