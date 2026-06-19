import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var auth = AuthManager.shared
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("signInShown") private var signInShown = false

    var body: some View {
        if !signInShown {
            SignInScreen {
                signInShown = true
            }
        } else if !onboardingComplete {
            OnboardingScreen {
                onboardingComplete = true
            }
        } else {
            MainScreen()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
