import SwiftUI
import Combine

struct CassetteLoadingScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData

    @State private var navigateToDesign = false
    @State private var progress: Double = 0.0
    @State private var dotCount = 0

    private let totalDuration: Double = 10.0
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 로띠 자리 (추후 교체)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appBlack, lineWidth: 1.5)
                        .frame(width: 240, height: 200)

                    VStack(spacing: 12) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 56))
                            .foregroundColor(.appBlack)
                        Text("developing your cassette")
                            .font(.appMicro)
                            .foregroundColor(.appDarkGray)
                    }
                }
                .padding(.bottom, 48)

                // 타이틀
                Text("making your cassette\(String(repeating: ".", count: dotCount + 1))")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(width: 280, alignment: .leading)
                    .padding(.bottom, 20)

                // 프로그레스 바
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#D0D0D0"))
                        .frame(width: 300, height: 6)
                    Capsule()
                        .fill(Color.appBlack)
                        .frame(width: 300 * CGFloat(progress), height: 6)
                        .animation(.linear(duration: 0.1), value: progress)
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToDesign) {
            SelectDesignScreen()
                .environmentObject(appState)
                .environmentObject(cassetteData)
        }
        .onReceive(timer) { _ in
            guard progress < 1.0 else { return }
            progress = min(1.0, progress + 0.1 / totalDuration)
            if progress >= 1.0 {
                navigateToDesign = true
            }
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 3
        }
        .onAppear {
            if cassetteData.isSpecial {
                startMusicGeneration()
            }
        }
    }

    private func startMusicGeneration() {
        Task {
            await MusicGPTService.requestGeneration(
                keywords: cassetteData.keywords,
                photoCount: cassetteData.selectedPhotos.count,
                cassetteID: cassetteData.cassetteID
            )
        }
    }
}
