import SwiftUI
import Combine
import Lottie

struct FilmProcessingView: View {
    let progress: Double  // 0.0 ~ 1.0

    @State private var dotCount: Int = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var dots: String {
        String(repeating: ".", count: dotCount + 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            LottieView(animation: .named("onboarding_1"))
                .playing(loopMode: .loop)
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                .padding(.bottom, 48)

            // "film processing..."
            Text("\(String(localized: "film processing"))\(dots)")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

            // 프로그레스 바
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appGray)
                    .frame(width: 300, height: 6)

                Capsule()
                    .fill(Color.white)
                    .frame(width: 300 * CGFloat(progress), height: 6)
                    .animation(.linear(duration: 0.2), value: progress)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }
}
