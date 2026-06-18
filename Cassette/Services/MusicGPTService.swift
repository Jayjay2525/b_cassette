import Foundation

struct MusicGPTService {

    private static let endpoint = URL(string: "https://api.musicgpt.com/api/public/v1/generate-simple")!

    static func requestGeneration(
        keywords: [String],
        photoCount: Int,
        cassetteID: UUID
    ) async {
        guard !keywords.isEmpty else { return }

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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskId = json["task_id"] as? String else {
            print("MusicGPT request failed")
            return
        }

        // Supabase에 task_id 저장
        guard let userID = AuthManager.shared.userID else { return }
        try? await SupabaseManager.shared.insertCassetteMusic(
            cassetteID: cassetteID,
            taskId: taskId,
            userID: userID
        )

        // cassetteData에 taskId 저장은 호출부에서 처리
        print("MusicGPT task started: \(taskId)")
    }

    private static func musicDuration(for photoCount: Int) -> Int {
        switch photoCount {
        case 5...15:  return 30
        case 16...30: return 60
        default:      return 120
        }
    }
}
