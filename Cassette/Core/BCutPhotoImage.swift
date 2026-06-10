import SwiftUI

/// BCutImageSource를 받아 적절한 이미지를 렌더링하는 공용 뷰.
/// - .asset: 에셋 카탈로그에서 로드 (mock용)
/// - .file: Documents의 URL에서 로드 (실제 유저 데이터)
struct BCutPhotoImage: View {
    let source: BCutImageSource

    var body: some View {
        switch source {
        case .asset:
            // TODO: 실제 에셋 이미지로 교체
            Color.appGray

        case .file(let url):
            if let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // TODO: 실제 파일로 교체
                Color.appGray
            }
        }
    }
}
