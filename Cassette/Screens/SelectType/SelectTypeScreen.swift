import SwiftUI

struct SelectTypeScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert = false
    @State private var navigateToLoading = false
    @State private var isSigningIn = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Navbar
                HStack {
                    Button { dismiss() } label: {
                        Image("button_chevronLeft")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Text("make a cassette")
                        .font(.appTitle)
                        .foregroundColor(.appBlack)
                    Spacer()
                    Button { showExitAlert = true } label: {
                        Image("button_x")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 48)

                Spacer()

                // 버튼 두 개
                VStack(spacing: 16) {
                    // normal
                    Button {
                        cassetteData.isSpecial = false
                        navigateToLoading = true
                    } label: {
                        VStack(spacing: 6) {
                            Text("normal cassette")
                                .font(.appBody)
                                .foregroundColor(.appBlack)
                            Text("random music from our library")
                                .font(.appMicro)
                                .foregroundColor(.appDarkGray)
                        }
                        .frame(width: 289, height: 72)
                        .background(Color.appWhite)
                    }

                    // special
                    Button {
                        handleSpecial()
                    } label: {
                        VStack(spacing: 6) {
                            Text("special cassette")
                                .font(.appBody)
                                .foregroundColor(.appWhite)
                            Text("ai-generated music for your film")
                                .font(.appMicro)
                                .foregroundColor(Color.appWhite.opacity(0.7))
                        }
                        .frame(width: 289, height: 72)
                        .background(Color.appBlack)
                    }
                }

                Spacer()
            }

            .navigationDestination(isPresented: $navigateToLoading) {
                CassetteLoadingScreen()
                    .environmentObject(appState)
                    .environmentObject(cassetteData)
            }
        }
        .navigationBarHidden(true)
        .alert("Leave without saving?", isPresented: $showExitAlert) {
            Button("leave", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("Your cassette won't be saved.")
        }
    }

    private func handleSpecial() {
        if AuthManager.shared.isSignedIn {
            cassetteData.isSpecial = true
            navigateToLoading = true
        } else {
            isSigningIn = true
            Task {
                try? await AuthManager.shared.signInWithApple()
                await MainActor.run {
                    isSigningIn = false
                    if AuthManager.shared.isSignedIn {
                        cassetteData.isSpecial = true
                        navigateToLoading = true
                    }
                }
            }
        }
    }
}
