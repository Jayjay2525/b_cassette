import SwiftUI

struct CassetteImageView: View {
    let cassette: CassetteModel
    var width: CGFloat = 345
    var height: CGFloat? = nil
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            if let relativePath = cassette.customImagePath,
               let uiImage = UIImage(contentsOfFile: FileManager.default
                   .urls(for: .documentDirectory, in: .userDomainMask)[0]
                   .appendingPathComponent(relativePath).path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(cassette.design.imageName)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            }
        }
        .frame(width: width, height: height)
    }
}
