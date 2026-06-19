import Foundation

struct MusicGPTService {

    private static let endpoint = URL(string: "https://api.musicgpt.com/api/public/v1/MusicAI")!

    @discardableResult
    static func requestGeneration(
        keywords: [String],
        photoCount: Int,
        cassetteID: UUID,
        cassetteName: String = ""
    ) async -> String? {
        guard !keywords.isEmpty else {
            print("MusicGPT: keywords empty, skipping")
            return nil
        }
        print("MusicGPT: requesting with keywords \(keywords), photoCount \(photoCount)")

        let duration = musicDuration(for: photoCount)
        let prompt = keywords.joined(separator: ", ")

        let apiKey = Config.musicGPTAPIKey

        let body: [String: Any] = [
            "prompt": prompt,
            "make_instrumental": true,
            "output_length": duration,
            "webhook_url": "https://kdrfkvfkrdmjfeuaxvpj.supabase.co/functions/v1/musicgpt-webhook"
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            print("MusicGPT network error")
            return nil
        }
        print("MusicGPT response: \(String(data: data, encoding: .utf8) ?? "nil")")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskId = json["task_id"] as? String else {
            print("MusicGPT parse failed")
            return nil
        }

        guard let userID = AuthManager.shared.userID else { return nil }
        try? await SupabaseManager.shared.insertCassetteMusic(
            cassetteID: cassetteID,
            taskId: taskId,
            userID: userID,
            cassetteName: cassetteName
        )

        print("MusicGPT task started: \(taskId)")
        return taskId
    }

    private static func musicDuration(for photoCount: Int) -> Int {
        switch photoCount {
        case 5...15:  return 30
        case 16...30: return 60
        default:      return 120
        }
    }
}
