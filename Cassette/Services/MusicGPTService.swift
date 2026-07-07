import Foundation

struct MusicGPTService {

    private static var endpoint: URL {
        URL(string: "\(Config.supabaseURL)/functions/v1/request-music")!
    }

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
        guard let userID = AuthManager.shared.userID else {
            print("MusicGPT: no userID")
            return nil
        }
        print("MusicGPT: requesting via Edge Function, keywords \(keywords), photoCount \(photoCount)")

        var body: [String: Any] = [
            "keywords": keywords,
            "photoCount": photoCount,
            "cassetteID": cassetteID.uuidString,
            "cassetteName": cassetteName,
            "userID": userID.uuidString,
        ]
        if let token = SupabaseManager.shared.deviceToken {
            body["deviceToken"] = token
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            print("MusicGPT network error")
            return nil
        }
        print("MusicGPT response: \(String(data: data, encoding: .utf8) ?? "nil")")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskId = json["taskId"] as? String else {
            print("MusicGPT parse failed")
            return nil
        }

        print("MusicGPT task started: \(taskId)")
        return taskId
    }
}
