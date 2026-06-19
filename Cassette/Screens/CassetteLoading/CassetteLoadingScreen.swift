import SwiftUI
import Combine
import Lottie

struct CassetteLoadingScreen: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData

    @State private var navigateToDesign = false
    @State private var progress: Double = 0.0
    @State private var dotCount = 0

    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                LottieView(animation: .named("onboarding_2"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                    .padding(.bottom, 48)

                Text("making your cassette\(String(repeating: ".", count: dotCount + 1))")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.appGray)
                        .frame(width: 300, height: 6)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 300 * CGFloat(progress), height: 6)
                        .animation(.linear(duration: 0.3), value: progress)
                }

                Spacer()
                Spacer().frame(height: 11)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToDesign) {
            SelectDesignScreen()
                .environmentObject(appState)
                .environmentObject(cassetteData)
        }
.onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 3
        }
        .onAppear {
            Task {
                for i in 1...40 {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        progress = Double(i) / 40.0
                    }
                }
                await MainActor.run { navigateToDesign = true }
            }
        }
    }
}
