import Foundation

enum Config {
    static func value(for key: String) -> String {
        guard let val = Bundle.main.infoDictionary?[key] as? String, !val.isEmpty else {
            fatalError("Missing Info.plist key: \(key)")
        }
        return val
    }

    static var anthropicAPIKey: String { value(for: "ANTHROPIC_API_KEY") }
    static var supabaseURL: String     { value(for: "SUPABASE_URL") }
    static var supabaseKey: String     { value(for: "SUPABASE_PUBLISHABLE_KEY") }
}
