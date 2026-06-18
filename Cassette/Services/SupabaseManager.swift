import Foundation
import Combine
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseKey
)

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    // MARK: - Cassette Music

    func insertCassetteMusic(cassetteID: UUID, taskId: String, userID: UUID) async throws {
        try await supabase
            .from("cassette_music")
            .insert([
                "cassette_id": cassetteID.uuidString,
                "task_id": taskId,
                "user_id": userID.uuidString,
                "status": "generating"
            ])
            .execute()
    }

    func fetchCassetteMusic(taskId: String) async throws -> (status: String, audioURL: String?) {
        let response = try await supabase
            .from("cassette_music")
            .select("status, audio_url")
            .eq("task_id", value: taskId)
            .single()
            .execute()

        let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        let status = json?["status"] as? String ?? "generating"
        let audioURL = json?["audio_url"] as? String
        return (status, audioURL)
    }

    // MARK: - Pending cassette 확인 (앱 진입 시)

    func checkPendingCassettes(cassettes: inout [CassetteModel]) async {
        for i in cassettes.indices where cassettes[i].status == .generating {
            guard let taskId = cassettes[i].taskId else { continue }
            guard let result = try? await fetchCassetteMusic(taskId: taskId) else { continue }

            if result.status == "completed", let urlString = result.audioURL {
                if let localURL = await downloadAudio(urlString: urlString, cassetteID: cassettes[i].id) {
                    cassettes[i].trackName = localURL.lastPathComponent
                    cassettes[i].status = .completed
                }
            } else if result.status == "failed" {
                cassettes[i].status = .failed
            }
        }
    }

    // MARK: - Special credit

    func checkAndIncrementCredit(userID: UUID) async throws -> Bool {
        let response = try? await supabase
            .from("special_credit")
            .select("used_count")
            .eq("user_id", value: userID.uuidString)
            .single()
            .execute()

        let json = try? JSONSerialization.jsonObject(with: response?.data ?? Data()) as? [String: Any]
        let usedCount = json?["used_count"] as? Int ?? 0

        guard usedCount < 3 else { return false }

        try await supabase
            .from("special_credit")
            .upsert([
                "user_id": userID.uuidString,
                "used_count": String(usedCount + 1)
            ])
            .execute()

        return true
    }

    // MARK: - Audio download

    private func downloadAudio(urlString: String, cassetteID: UUID) async -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cassettes/\(cassetteID.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let dest = dir.appendingPathComponent("track.mp3")
        try? data.write(to: dest)
        return dest
    }
}
