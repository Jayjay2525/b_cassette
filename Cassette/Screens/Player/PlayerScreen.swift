import SwiftUI

struct PlayerScreen: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Text("Player Screen")
                .font(.cutiveMono(20))
        }
    }
}

#Preview {
    PlayerScreen()
        .environmentObject(AppState())
}
