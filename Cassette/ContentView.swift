import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            MainScreen()
        } else {
            OnboardingScreen {
                onboardingComplete = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
