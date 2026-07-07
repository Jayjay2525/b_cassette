import UIKit

struct ClaudeAPIService {

    private static let endpoint = URL(string: "\(Config.supabaseURL)/functions/v1/extract-keywords")!

    /// 이미지 최대 5장을 분석해 키워드 3개 반환 (Supabase Edge Function 경유)
    static func extractKeywords(from images: [UIImage]) async throws -> [String] {
        let samples = Array(images.shuffled().prefix(5))
        let base64Images = samples.compactMap { resized($0) }

        let body: [String: Any] = ["images": base64Images]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let keywords = json["keywords"] as? [String],
            keywords.count == 3
        else {
            throw APIError.invalidResponse
        }

        return keywords
    }

    // 긴 변 512px 이하로 리사이즈 후 base64
    private static func resized(_ image: UIImage) -> String? {
        let maxDim: CGFloat = 512
        let size = image.size
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resizedImage.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }

    enum APIError: Error {
        case invalidResponse
    }
}
