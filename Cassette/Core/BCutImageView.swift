import SwiftUI
import Photos

/// BCutImageSource에 맞게 이미지를 비동기 로드하는 범용 뷰.
struct BCutImageView: View {
    let source: BCutImageSource
    let width: CGFloat
    let height: CGFloat

    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.appGray.opacity(0.4)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear { loadImage() }
    }

    private func loadImage() {
        switch source {
        case .asset(let id):
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = result.firstObject else { return }
            let size = CGSize(width: width * 3, height: height * 3)
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
                if let img { DispatchQueue.main.async { image = img } }
            }

        case .file(let url):
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = try? Data(contentsOf: url), let ui = UIImage(data: data) else { return }
                DispatchQueue.main.async { image = ui }
            }
        case .bundleAsset(let name):
            if let img = UIImage(named: name) { image = img }
        }
    }
}
