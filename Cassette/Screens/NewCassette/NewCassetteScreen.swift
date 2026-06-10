import SwiftUI

struct NewCassetteScreen: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject var cassetteData = NewCassetteData()

    var body: some View {
        NavigationStack {
            SelectBCutsScreen()
                .environmentObject(appState)
                .environmentObject(cassetteData)
        }
        .onReceive(cassetteData.$shouldDismiss) { should in
            if should { dismiss() }
        }
    }
}

#Preview {
    NewCassetteScreen()
        .environmentObject(AppState())
}
