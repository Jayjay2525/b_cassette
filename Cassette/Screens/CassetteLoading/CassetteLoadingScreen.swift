import SwiftUI
import Lottie

struct CassetteLoadingOverlay: View {
    let progress: Double

    @State private var dotCount = 0

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                LottieView(animation: .named("onboarding_2"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                    .padding(.bottom, 48)

                Text("winding your tape\(String(repeating: ".", count: dotCount + 1))")
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
                        .animation(.linear(duration: 0.1), value: progress)
                }

                Spacer()
                Spacer().frame(height: 11)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}
