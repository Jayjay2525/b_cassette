import SwiftUI
import Combine

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

            // 일러스트 영역 (추후 Lottie로 교체)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBlack, lineWidth: 1.5)
                    .frame(width: 200, height: 160)

                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.appBlack)
                    Text("developing")
                        .font(.appMicro)
                        .foregroundColor(.appDarkGray)
                }
            }
            .padding(.bottom, 48)

            // "film processing..."
            Text("film processing\(dots)")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .frame(width: 240, alignment: .leading)
                .padding(.bottom, 20)

            // 프로그레스 바
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#D0D0D0"))
                    .frame(width: 300, height: 6)

                Capsule()
                    .fill(Color.appBlack)
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
