import SwiftUI

struct SelectTypePopup: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData

    let onDismiss: () -> Void
    let onSelect: (Bool) -> Void

    @State private var isSigningIn = false

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
                    VStack(spacing: 8) {
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
                VStack(spacing: 6) {
                    Button { handleSpecial() } label: {
                        ZStack {
                            VStack(spacing: 8) {
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
                                Text("free (3/3)")
                                    .font(.appBody)
                                    .foregroundColor(.appWhite.opacity(0.7))
                            }
                            .padding(.vertical, 10)

                            if isSigningIn {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .appWhite))
                            }
                        }
                        .frame(width: 233, height: 124)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appBlack))
                    }
                    .disabled(isSigningIn)

                    Text("sign-in required")
                        .font(.appMicro)
                        .foregroundColor(.appDarkGray)
                }

                Spacer().frame(height: 8)
            }
            .frame(width: 313)
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
                    onSelect(true)
                } catch {
                    isSigningIn = false
                    print("SignIn error: \(error)")
                }
            }
        }
    }
}
