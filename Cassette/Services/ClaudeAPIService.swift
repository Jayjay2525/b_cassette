import UIKit

struct ClaudeAPIService {

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// 이미지 최대 5장을 분석해 키워드 3개 반환
    static func extractKeywords(from images: [UIImage]) async throws -> [String] {
        let samples = Array(images.shuffled().prefix(5))
        let base64Images = samples.compactMap { resized($0) }

        var content: [[String: Any]] = base64Images.map { b64 in
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": b64
                ]
            ]
        }
        content.append([
            "type": "text",
            "text": """
            Look at these photos and extract exactly 3 keywords that best describe \
            the mood, atmosphere, and feeling of these moments. \
            Keywords MUST be in English only. Never use any other language. \
            Return ONLY a JSON array of 3 English strings. No explanation, no preamble. \
            Example: ["golden hour", "nostalgic", "friends"]
            """
        ])

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 64,
            "messages": [["role": "user", "content": content]]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = (json["content"] as? [[String: Any]])?.first,
            let text = content["text"] as? String,
            let jsonData = text.data(using: .utf8),
            let keywords = try JSONSerialization.jsonObject(with: jsonData) as? [String],
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
