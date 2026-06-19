import SwiftUI
import Photos
import Lottie
import UserNotifications

struct OnboardingScreen: View {
    let onComplete: () -> Void

    @State private var page: Int = OnboardingScreen.initialPage()
    @State private var opacity: Double = 0

    static func initialPage() -> Int {
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if photoStatus == .notDetermined { return 0 }
        if UserDefaults.standard.bool(forKey: "onboarding_notif_shown") { return 2 }
        return 1
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            // ── 페이드 대상 콘텐츠 ──
            ZStack(alignment: .bottom) {
                // 일러스트 영역 (스텝 레이블)
                VStack(spacing: 0) {
                    HStack {
                        Text(page == 0 ? "(1) b-cuts    → →     film" : page == 1 ? "(2) film      → →      cassette" : "(3) notifications")
                            .font(.appTitle)
                            .foregroundColor(.appBlack)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 64)

                    Spacer()
                }

                // 일러스트 애니메이션
                LottieView(animation: .named(page == 0 ? "onboarding_1" : page == 1 ? "onboarding_2" : "onboarding_3"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .offset(y: -30)

                // 하단 패널 + 버튼
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            if page == 2 { onComplete() } else { exit(0) }
                        } label: {
                            Text(page == 2 ? "skip" : "exit")
                                .font(.appBody)
                                .foregroundColor(.appBlack)
                        }

                        Spacer()

                        Button { handleAllow() } label: {
                            Text("allow")
                                .font(.appBody)
                                .foregroundColor(.appAccent)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    OnboardingInfoPanel(page: page)
                        .padding(.bottom, 40)
                }
            }
            .opacity(opacity)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { opacity = 1 }
        }
    }

    private func handleAllow() {
        if page == 0 {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in
                DispatchQueue.main.async { advancePage() }
            }
        } else if page == 1 {
            advancePage()
        } else {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    onComplete()
                }
            }
        }
    }

    private func advancePage() {
        withAnimation(.easeOut(duration: 0.25)) { opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            page += 1
            if page == 2 {
                UserDefaults.standard.set(true, forKey: "onboarding_notif_shown")
            }
            withAnimation(.easeIn(duration: 0.5)) { opacity = 1 }
        }
    }
}

// MARK: - 온보딩 정보 패널

struct OnboardingInfoPanel: View {
    let page: Int

    private var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    private var learnMoreURL: URL {
        if page == 0 {
            let str = isKorean
                ? "https://polydactyl-alder-784.notion.site/3821d0eacd8f805cbc5acd1d34118336"
                : "https://polydactyl-alder-784.notion.site/Photos-Access-3821d0eacd8f8033acbdc5ba3ac99781"
            return URL(string: str)!
        } else {
            let str = isKorean
                ? "https://polydactyl-alder-784.notion.site/AI-3821d0eacd8f80378da2fc79678b0258"
                : "https://polydactyl-alder-784.notion.site/AI-Music-Generation-3821d0eacd8f801b9b1bee3dfb082854"
            return URL(string: str)!
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if page == 0 {
                Text("Photos access")
                    .font(.appHeader)
                    .foregroundColor(.appBlack)
                    .frame(height: 30)
                Text("films are made out of your b-cuts")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(height: 23)
                Text("so we ask permission of photos")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(height: 23)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else if page == 1 {
                Text("AI music generation")
                    .font(.appHeader)
                    .foregroundColor(.appBlack)
                    .frame(height: 30)
                Text("cassette is made by ai with film")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(height: 23)
                Text("so we ask permission of ai usage")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(height: 23)
            } else {
                Text("Notifications")
                    .font(.appHeader)
                    .foregroundColor(.appBlack)
                    .frame(height: 30)
                Text("we can notify you when ai music")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(height: 23)
                Text("generation is all finished")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .frame(height: 23)
            }

            if page < 2 {
                Link("learn more", destination: learnMoreURL)
                    .font(.custom("SF Mono", size: 13).monospaced())
                    .kerning(13 * 0.08)
                    .foregroundColor(.appDarkGray)
                    .underline()
                    .frame(height: 23)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .frame(width: 345, height: 140, alignment: .topLeading)
        .background(Color.appWhite)
        .overlay(Rectangle().stroke(Color.appBlack, lineWidth: 1))
    }
}

#Preview {
    OnboardingScreen(onComplete: {})
}
