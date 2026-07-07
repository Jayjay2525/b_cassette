import SwiftUI
import Supabase

struct SelectTypePopup: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData

    let onDismiss: () -> Void
    let onSelect: (Bool) -> Void

    @State private var isSigningIn = false
    @State private var usedCount: Int = 0

    private let maxFreeSpecial = 3
    private var remainingSpecial: Int { max(0, maxFreeSpecial - usedCount) }
    private var isSpecialExhausted: Bool { remainingSpecial == 0 }

    var body: some View {
        ZStack {
            Image("pop_up_box")
                .resizable()
                .scaledToFit()
                .frame(width: 313)

            VStack(spacing: 16) {
                // ── 상단 헤더 ──
                HStack {
                    Color.clear.frame(width: 24, height: 24)
                    Spacer()
                    Text("select types")
                        .font(.appTitle)
                        .foregroundColor(.appBlack)
                    Spacer()
                    Button { onDismiss() } label: {
                        Image("button_x")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 24)

                // ── 버튼 1: normal cassette ──
                Button { onSelect(false) } label: {
                    VStack(spacing: 10) {
                        Text("normal cassette")
                            .font(.appBody)
                            .foregroundColor(.appBlack)
                        Image("line_scrib_b")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180)
                        Text("random music from\nour library tracks")
                            .font(.appMicro)
                            .foregroundColor(.appDarkGray)
                            .multilineTextAlignment(.center)
                        Text("free")
                            .font(.appBody)
                            .foregroundColor(.appDarkGray)
                    }
                    .padding(.vertical, 10)
                    .frame(width: 233, height: 124)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.appWhite))
                }

                // ── 버튼 2: special cassette ──
                VStack(spacing: 8) {
                    Button { handleSpecial() } label: {
                        ZStack {
                            VStack(spacing: 10) {
                                Text("special cassette")
                                    .font(.appBody)
                                    .foregroundColor(.appWhite)
                                Image("line_scrib_w")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180)
                                Text("fitting music from\nai generation")
                                    .font(.appMicro)
                                    .foregroundColor(.appWhite.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                Text(String(format: NSLocalizedString("free (%d/%d)", comment: ""), remainingSpecial, maxFreeSpecial))
                                    .font(.appBody)
                                    .foregroundColor(.appWhite.opacity(0.7))
                            }
                            .padding(.vertical, 10)

                            if !isSpecialExhausted {
                                Image("sparkles")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 233)
                                    .allowsHitTesting(false)
                            }

                            if isSigningIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appWhite))
                            }
                        }
                        .frame(width: 233, height: 124)
                        .background(RoundedRectangle(cornerRadius: 12).fill(isSpecialExhausted ? Color.appGray : Color.appBlack))
                    }
                    .disabled(isSigningIn || isSpecialExhausted)

                    if !AuthManager.shared.isSignedIn {
                        Text("sign-in required")
                            .font(.appMicro)
                            .foregroundColor(.appDarkGray)
                    } else if isSpecialExhausted {
                        Text("free chance all used!")
                            .font(.appMicro)
                            .foregroundColor(.appAccent)
                    }
                }

                Spacer().frame(height: 8)
            }
            .frame(width: 313)
        }
        .onAppear { fetchUsedCount() }
    }

    private func fetchUsedCount() {
        guard let userID = AuthManager.shared.userID else { return }
        Task {
            let response = try? await supabase
                .from("special_credit")
                .select("used_count")
                .eq("user_id", value: userID.uuidString)
                .single()
                .execute()
            let json = try? JSONSerialization.jsonObject(with: response?.data ?? Data()) as? [String: Any]
            let count = json?["used_count"] as? Int ?? 0
            await MainActor.run { usedCount = count }
        }
    }

    private func handleSpecial() {
        if AuthManager.shared.isSignedIn {
            onSelect(true)
        } else {
            isSigningIn = true
            Task {
                do {
                    try await AuthManager.shared.signInWithApple()
                    isSigningIn = false
                    // 로그인 후 크레딧 확인만 하고 버튼을 다시 누르게 유도
                    fetchUsedCount()
                } catch {
                    isSigningIn = false
                    print("SignIn error: \(error)")
                }
            }
        }
    }
}
