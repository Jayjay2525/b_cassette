import SwiftUI
import Combine
import Photos

// MARK: - CassetteStatus

enum CassetteStatus: String, Codable {
    case generating
    case completed
    case failed
}

// MARK: - CassetteModel

struct CassetteModel: Identifiable, Codable {
    let id: UUID
    var name: String
    var createdAt: Date
    var expiresAt: Date
    var photos: [BCutPhoto]
    var keywords: [String]
    var design: CassetteDesign
    var customImagePath: String? = nil  // 렌더링된 커스텀 카세트 PNG 경로
    var printProgress: Double  // 0.0 → 1.0 (현상 애니메이션)
    var trackName: String      // 로컬 사운드 파일 이름 (확장자 포함)
    var status: CassetteStatus = .completed
    var taskId: String? = nil

    var daysLeft: Int {
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
        return max(0, diff)
    }

    var isExpired: Bool { daysLeft == 0 }

    var bCuts: [BCutPhoto] { photos.filter { $0.isBCut } }
    var aCuts: [BCutPhoto] { photos.filter { !$0.isBCut } }

    var photoDateRange: (oldest: Date, latest: Date)? {
        guard !photos.isEmpty else { return nil }
        let dates = photos.map { $0.takenAt }
        return (dates.min()!, dates.max()!)
    }
}

// MARK: - Image Source

enum BCutImageSource: Codable {
    case asset(String)
    case file(URL)

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    enum CodingKeys: String, CodingKey { case type, value }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        let value = try c.decode(String.self, forKey: .value)
        if type == "asset" {
            self = .asset(value)
        } else {
            self = .file(Self.documentsURL.appendingPathComponent(value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .asset(let name):
            try c.encode("asset", forKey: .type)
            try c.encode(name, forKey: .value)
        case .file(let url):
            let relative = url.path.replacingOccurrences(
                of: Self.documentsURL.path + "/", with: ""
            )
            try c.encode("file", forKey: .type)
            try c.encode(relative, forKey: .value)
        }
    }
}

// MARK: - BCutPhoto

struct BCutPhoto: Identifiable, Codable {
    let id: UUID
    var imageSource: BCutImageSource
    var isBCut: Bool
    var takenAt: Date
}

// MARK: - CassetteDesign

enum CassetteDesign: String, CaseIterable, Codable {
    case d1 = "cassette_1"
    case d2 = "cassette_2"
    case d3 = "cassette_3"
    case d4 = "cassette_4"
    case d5 = "cassette_5"
    case d6 = "cassette_6"
    case d7 = "cassette_7"
    case d8 = "cassette_8"
    case d9 = "cassette_9"

    var imageName: String { rawValue }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var cassettes: [CassetteModel] = [] {
        didSet { saveCassettes() }
    }
    @Published var selectedCassetteID: UUID? = nil

    private let cassettesKey = "saved_cassettes"

    init() {
        loadCassettes()
    }

    private func saveCassettes() {
        if let data = try? JSONEncoder().encode(cassettes) {
            UserDefaults.standard.set(data, forKey: cassettesKey)
        }
    }

    private func loadCassettes() {
        guard let data = UserDefaults.standard.data(forKey: cassettesKey),
              let saved = try? JSONDecoder().decode([CassetteModel].self, from: data) else { return }
        cassettes = saved
    }

    var isFull: Bool { cassettes.count >= AppConstants.maxCassettes }

    // MARK: - Cassette 관리

    func addCassette(_ cassette: CassetteModel) {
        cassettes.append(cassette)
        if cassette.status == .generating {
            startMusicGeneration(for: cassette)
        }
    }

    private func startMusicGeneration(for cassette: CassetteModel) {
        let cassetteID = cassette.id
        let keywords = cassette.keywords
        let photoCount = cassette.photos.count
        print("[AppState] startMusicGeneration — cassetteID: \(cassetteID), keywords: \(keywords)")
        Task {
            let taskId = await MusicGPTService.requestGeneration(
                keywords: keywords,
                photoCount: photoCount,
                cassetteID: cassetteID
            )
            guard let taskId else {
                print("[AppState] MusicGPT returned no taskId, aborting")
                return
            }
            print("[AppState] taskId received: \(taskId), saving to cassette")
            await MainActor.run {
                if let idx = cassettes.firstIndex(where: { $0.id == cassetteID }) {
                    cassettes[idx].taskId = taskId
                }
            }
            await SupabaseManager.shared.pollUntilComplete(taskId: taskId, cassetteID: cassetteID, appState: self)
        }
    }

    func updateCassetteStatus(id: UUID, status: CassetteStatus) {
        if let idx = cassettes.firstIndex(where: { $0.id == id }) {
            cassettes[idx].status = status
        }
    }

    /// 카세트 자체를 삭제 (로컬 파일 + 데이터 모두 제거)
    func deleteCassette(id: UUID) {
        guard let cassette = cassettes.first(where: { $0.id == id }) else { return }
        deleteLocalFiles(for: cassette)
        cassettes.removeAll { $0.id == id }
    }

    /// 만료된 카세트 자동 정리 (앱 시작 시 호출)
    func purgeExpiredCassettes() {
        // 만료는 UI 상태만 변경 (revert 버튼 비활성화 등)
        // 파일 삭제 없음 — 사용자가 Photos 앱에서 직접 복구할 수 있도록 유지
    }

    // MARK: - B-cut 저장 (Photos → Documents)

    /// PHAsset에서 이미지를 추출해 Documents에 저장하고 BCutPhoto를 반환
    /// - 저장 경로: Documents/cassettes/{cassetteID}/{photoID}.heic
    func saveBCut(
        asset: PHAsset,
        cassetteID: UUID,
        isBCut: Bool,
        completion: @escaping (BCutPhoto?) -> Void
    ) {
        let photoID = UUID()
        let destURL = localURL(cassetteID: cassetteID, photoID: photoID)

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        // 1080px 기준으로 리사이즈해서 요청
        let targetSize = CGSize(width: 1080, height: 1080)
        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
            guard let image,
                  let jpegData = image.jpegData(compressionQuality: 0.75) else {
                completion(nil)
                return
            }
            do {
                try FileManager.default.createDirectory(
                    at: destURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try jpegData.write(to: destURL)
                let photo = BCutPhoto(
                    id: photoID,
                    imageSource: .file(destURL),
                    isBCut: isBCut,
                    takenAt: asset.creationDate ?? Date()
                )
                DispatchQueue.main.async { completion(photo) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// Photos 라이브러리에서 에셋 삭제
    func deleteFromPhotos(assets: [PHAsset], completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    // MARK: - Revert (Documents → Photos 복원)

    /// B-cut 사진들을 Photos 라이브러리에 복원하고 로컬 파일 삭제
    func revertBCuts(of cassette: CassetteModel, completion: @escaping (Bool) -> Void) {
        let bCuts = cassette.bCuts
        let fileURLs: [URL] = bCuts.compactMap {
            if case .file(let url) = $0.imageSource { return url }
            return nil
        }

        guard !fileURLs.isEmpty else {
            completion(true)
            return
        }

        var successCount = 0
        let group = DispatchGroup()

        for url in fileURLs {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { continue }

            group.enter()
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, _ in
                if success { successCount += 1 }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            // 복원 완료 후 카세트 삭제
            self.deleteCassette(id: cassette.id)
            completion(successCount == fileURLs.count)
        }
    }

    // MARK: - Helpers

    /// 카세트 디렉토리 내 로컬 파일 전체 삭제
    private func deleteLocalFiles(for cassette: CassetteModel) {
        let dir = localCassetteDir(cassetteID: cassette.id)
        try? FileManager.default.removeItem(at: dir)
    }

    /// cassetteID로 직접 로컬 파일 삭제 (Don't Allow 시 rollback용)
    func deleteLocalFiles(cassetteID: UUID) {
        let dir = localCassetteDir(cassetteID: cassetteID)
        try? FileManager.default.removeItem(at: dir)
    }

    /// Documents/cassettes/{cassetteID}/{photoID}.heic
    private func localURL(cassetteID: UUID, photoID: UUID) -> URL {
        localCassetteDir(cassetteID: cassetteID)
            .appendingPathComponent("\(photoID.uuidString).heic")
    }

    /// Documents/cassettes/{cassetteID}/
    private func localCassetteDir(cassetteID: UUID) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cassettes/\(cassetteID.uuidString)")
    }
}
