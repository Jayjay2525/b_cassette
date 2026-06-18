import SwiftUI
import Combine
import Lottie

struct CassetteLoadingScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData

    @State private var navigateToDesign = false
    @State private var progress: Double = 0.0
    @State private var dotCount = 0
    @State private var showSkip = false
    @State private var taskId: String? = nil
    @State private var pollingTask: Task<Void, Never>? = nil

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
                        .fill(Color(hex: "#D0D0D0"))
                        .frame(width: 300, height: 6)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 300 * CGFloat(progress), height: 6)
                        .animation(.linear(duration: 0.3), value: progress)
                }

                Spacer()

                if showSkip {
                    VStack(spacing: 16) {
                        Text("taking longer than expected.\npick a design first?")
                            .font(.appMicro)
                            .foregroundColor(.appDarkGray)
                            .multilineTextAlignment(.center)

                        Button {
                            pollingTask?.cancel()
                            navigateToDesign = true
                        } label: {
                            Text("next")
                                .font(.appBody)
                                .foregroundColor(.appWhite)
                                .frame(width: 201, height: 48)
                                .background(Capsule().fill(Color(hex: "#555555")))
                        }
                    }
                    .transition(.opacity)
                }

                Spacer().frame(height: 11)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToDesign) {
            SelectDesignScreen()
                .environmentObject(appState)
                .environmentObject(cassetteData)
        }
        .onDisappear {
            pollingTask?.cancel()
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 3
        }
        .onAppear {
            if cassetteData.isSpecial {
                startSpecialFlow()
            } else {
                startNormalFlow()
            }
        }
    }

    // MARK: - Normal: 10초 타이머 후 자동 이동
    private func startNormalFlow() {
        Task {
            for i in 1...100 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    progress = Double(i) / 100.0
                }
            }
            await MainActor.run { navigateToDesign = true }
        }
    }

    // MARK: - Special: MusicGPT 호출 + polling
    private func startSpecialFlow() {
        Task {
            // 0→70%를 15초에 걸쳐 채움
            let steps = 150
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    progress = 0.7 * Double(i) / Double(steps)
                }
            }

            // 70% 도달 후 안내 문구 + next 버튼 표시
            await MainActor.run {
                withAnimation { showSkip = true }
            }

            // MusicGPT 요청
            let id = await MusicGPTService.requestGeneration(
                keywords: cassetteData.keywords,
                photoCount: cassetteData.selectedPhotos.count,
                cassetteID: cassetteData.cassetteID
            )
            await MainActor.run {
                taskId = id
                cassetteData.musicTaskId = id
            }

            // 완료될 때까지 3초마다 polling
            guard let id else { return }
            pollingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 7_000_000_000)
                    let music = try? await SupabaseManager.shared.fetchCassetteMusic(taskId: id)
                    if music?.status == "completed" {
                        await MainActor.run {
                            cassetteData.musicCompleted = true
                            withAnimation(.linear(duration: 0.5)) { progress = 1.0 }
                        }
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await MainActor.run { navigateToDesign = true }
                        return
                    }
                }
            }
        }
    }
}

