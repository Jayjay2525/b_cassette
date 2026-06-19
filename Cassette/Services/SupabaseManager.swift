import Foundation
import Combine
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseKey,
    options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
)

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    // MARK: - Cassette Music

    func insertCassetteMusic(cassetteID: UUID, taskId: String, userID: UUID) async throws {
        print("[Supabase] inserting cassette_music — cassetteID: \(cassetteID), taskId: \(taskId)")
        do {
            try await supabase
                .from("cassette_music")
                .insert([
                    "cassette_id": cassetteID.uuidString,
                    "task_id": taskId,
                    "user_id": userID.uuidString,
                    "status": "generating"
                ])
                .execute()
            print("[Supabase] insertCassetteMusic success")
        } catch {
            print("[Supabase] insertCassetteMusic error: \(error)")
            throw error
        }
    }

    func fetchCassetteMusic(taskId: String) async throws -> (status: String, audioURL: String?) {
        print("[Supabase] fetchCassetteMusic — taskId: \(taskId)")
        let response = try await supabase
            .from("cassette_music")
            .select("status, audio_url")
            .eq("task_id", value: taskId)
            .single()
            .execute()

        let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        let status = json?["status"] as? String ?? "generating"
        let audioURL = json?["audio_url"] as? String
        print("[Supabase] fetchCassetteMusic result — status: \(status), audioURL: \(audioURL ?? "nil")")
        return (status, audioURL)
    }

    // MARK: - Pending cassette 확인 (앱 진입 시)

    func checkPendingCassettes(appState: AppState) async {
        let pending = appState.cassettes.filter { $0.status == .generating }
        print("[Supabase] checkPendingCassettes — \(pending.count) generating cassette(s) found")

        for i in appState.cassettes.indices where appState.cassettes[i].status == .generating {
            guard let taskId = appState.cassettes[i].taskId else {
                print("[Supabase] cassette \(appState.cassettes[i].id) has no taskId, skipping")
                continue
            }
            print("[Supabase] checking cassette \(appState.cassettes[i].id) — taskId: \(taskId)")
            guard let result = try? await fetchCassetteMusic(taskId: taskId) else {
                print("[Supabase] fetch failed for taskId: \(taskId)")
                continue
            }

            if result.status == "completed", let urlString = result.audioURL {
                print("[Supabase] completed — downloading audio from \(urlString)")
                if let localURL = await downloadAudio(urlString: urlString, cassetteID: appState.cassettes[i].id) {
                    await MainActor.run {
                        appState.cassettes[i].trackName = localURL.lastPathComponent
                        appState.cassettes[i].status = .completed
                        print("[Supabase] cassette updated to completed, trackName: \(localURL.lastPathComponent)")
                    }
                } else {
                    print("[Supabase] audio download failed")
                }
            } else if result.status == "completed" {
                print("[Supabase] ⚠️ status=completed but audio_url is nil — check webhook")
            } else if result.status == "failed" {
                print("[Supabase] cassette failed")
                await MainActor.run {
                    appState.cassettes[i].status = .failed
                }
            } else {
                print("[Supabase] still generating (status: \(result.status))")
            }
        }
    }

    func pollUntilComplete(taskId: String, cassetteID: UUID, appState: AppState) async {
        print("[Supabase] pollUntilComplete started — taskId: \(taskId), cassetteID: \(cassetteID)")
        while true {
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            print("[Supabase] polling... taskId: \(taskId)")
            guard let result = try? await fetchCassetteMusic(taskId: taskId) else {
                print("[Supabase] poll fetch failed, retrying")
                continue
            }
            if result.status == "completed", let urlString = result.audioURL {
                print("[Supabase] poll completed — downloading audio from \(urlString)")
                if let localURL = await downloadAudio(urlString: urlString, cassetteID: cassetteID) {
                    await MainActor.run {
                        if let idx = appState.cassettes.firstIndex(where: { $0.id == cassetteID }) {
                            appState.cassettes[idx].trackName = localURL.lastPathComponent
                            appState.cassettes[idx].status = .completed
                            print("[Supabase] cassette completed, trackName: \(localURL.lastPathComponent)")
                        }
                    }
                } else {
                    print("[Supabase] audio download failed")
                }
                return
            } else if result.status == "completed" {
                print("[Supabase] ⚠️ status=completed but audio_url is nil — webhook may not be setting audio_url. retrying in 7s")
            } else if result.status == "failed" {
                print("[Supabase] cassette generation failed")
                await MainActor.run {
                    if let idx = appState.cassettes.firstIndex(where: { $0.id == cassetteID }) {
                        appState.cassettes[idx].status = .failed
                    }
                }
                return
            } else {
                print("[Supabase] still generating (status: \(result.status)), will retry in 7s")
            }
        }
    }

    // MARK: - Special credit

    func checkAndIncrementCredit(userID: UUID) async throws -> Bool {
        print("[Supabase] checkAndIncrementCredit — userID: \(userID)")
        let response = try? await supabase
            .from("special_credit")
            .select("used_count")
            .eq("user_id", value: userID.uuidString)
            .single()
            .execute()

        let json = try? JSONSerialization.jsonObject(with: response?.data ?? Data()) as? [String: Any]
        let usedCount = json?["used_count"] as? Int ?? 0
        print("[Supabase] current used_count: \(usedCount)")

        guard usedCount < 3 else {
            print("[Supabase] credit limit reached")
            return false
        }

        try await supabase
            .from("special_credit")
            .upsert([
                "user_id": userID.uuidString,
                "used_count": String(usedCount + 1)
            ])
            .execute()
        print("[Supabase] credit incremented to \(usedCount + 1)")
        return true
    }

    // MARK: - Audio download

    private func downloadAudio(urlString: String, cassetteID: UUID) async -> URL? {
        print("[Supabase] downloadAudio — url: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("[Supabase] invalid audio URL")
            return nil
        }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            print("[Supabase] audio download network error")
            return nil
        }

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cassettes/\(cassetteID.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let dest = dir.appendingPathComponent("track.mp3")
        try? data.write(to: dest)
        print("[Supabase] audio saved to \(dest.path)")
        return dest
    }
}
