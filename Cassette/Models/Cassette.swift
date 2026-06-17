import SwiftUI
import Combine
import Photos

// MARK: - CassetteModel

struct CassetteModel: Identifiable {
    let id: UUID
    var name: String
    var createdAt: Date
    var expiresAt: Date
    var photos: [BCutPhoto]
    var keywords: [String]
    var design: CassetteDesign
    var printProgress: Double  // 0.0 → 1.0 (현상 애니메이션)
    var trackName: String      // 로컬 사운드 파일 이름 (확장자 포함)

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

enum BCutImageSource {
    case asset(String)   // 개발용 mock (에셋 카탈로그 이름)
    case file(URL)       // 실제 유저 데이터 (Documents 저장 경로)
    // 추후: case remote(URL)  // 클라우드 URL
}

// MARK: - BCutPhoto

struct BCutPhoto: Identifiable {
    let id: UUID
    var imageSource: BCutImageSource
    var isBCut: Bool
    var takenAt: Date
}

// MARK: - CassetteDesign

enum CassetteDesign: String, CaseIterable {
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
    @Published var cassettes: [CassetteModel] = []
    @Published var selectedCassetteID: UUID? = nil

    var isFull: Bool { cassettes.count >= AppConstants.maxCassettes }

    // MARK: - Cassette 관리

    func addCassette(_ cassette: CassetteModel) {
        cassettes.append(cassette)
    }

    /// 카세트 자체를 삭제 (로컬 파일 + 데이터 모두 제거)
    func deleteCassette(id: UUID) {
        guard let cassette = cassettes.first(where: { $0.id == id }) else { return }
        deleteLocalFiles(for: cassette)
        cassettes.removeAll { $0.id == id }
    }

    /// 만료된 카세트 자동 정리 (앱 시작 시 호출)
    func purgeExpiredCassettes() {
        let expired = cassettes.filter { $0.isExpired }
        expired.forEach { deleteCassette(id: $0.id) }
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

        // 원본 데이터 요청
        let options = PHImageRequestOptions()
        options.version = .original
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            guard let data else {
                completion(nil)
                return
            }
            do {
                try FileManager.default.createDirectory(
                    at: destURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: destURL)
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
