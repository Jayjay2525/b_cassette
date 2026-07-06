import SwiftUI

struct SelectDetailScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert: Bool = false
    @State private var navigateToDesign: Bool = false
    @State private var isLoading: Bool = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingTask: Task<Void, Never>? = nil
    @State private var keywordInput1: String = ""
    @State private var keywordInput2: String = ""
    @State private var keywordInput3: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var keyword1Focused: Bool
    @FocusState private var keyword2Focused: Bool
    @FocusState private var keyword3Focused: Bool

    private func suggested(_ index: Int) -> String {
        cassetteData.suggestedKeywords.count > index ? cassetteData.suggestedKeywords[index] : ""
    }

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    var dateRangeString: String {
        let dates = cassetteData.selectedPhotos.map { $0.takenAt }
        guard let earliest = dates.min(), let latest = dates.max() else { return "--" }
        if fmt.string(from: earliest) == fmt.string(from: latest) {
            return fmt.string(from: earliest)
        }
        return "\(fmt.string(from: earliest))  —  \(fmt.string(from: latest))"
    }

    var body: some View {
        ZStack {
        ZStack(alignment: .bottom) {
        ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {

            // ── 1. Navbar ──
            HStack {
                Button {
                    cassetteData.resetForReselection()
                    cassetteData.draftImageLayers = []
                    cassetteData.draftTextLayers = []
                    cassetteData.draftOrderedLayerIDs = []
                    cassetteData.draftImageCreationOrder = []
                    cassetteData.draftTextCreationOrder = []
                    dismiss()
                } label: {
                    Image("button_chevronLeft")
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                }
                Spacer()
                Text("make a film")
                    .font(.appTitle)
                    .foregroundColor(.appBlack)
                Spacer()
                Button { showExitAlert = true } label: {
                    Image("button_x")
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // ── 2. title ──
            Text("[title]")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            // ── 3. 이름 입력 ──
            HStack(spacing: 8) {
                Color.clear.frame(width: 24, height: 24)

                TextField(text: $cassetteData.name, prompt: Text("film \(appState.cassettes.count + 1)").foregroundColor(.appGray)) { }
                    .font(.appTitle)
                    .foregroundColor(.appBlack)
                    .multilineTextAlignment(.center)
                    .focused($nameFieldFocused)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 257, height: 26)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 16)
                    .background(Color.appWhite)
                    .frame(width: 289, height: 36)

                Button {
                    nameFieldFocused = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.appBlack)
                }
                .frame(width: 24, height: 24)
            }
            .padding(.bottom, 8)

            // ── 4. 날짜 ──
            Text(dateRangeString)
                .font(.appBody)
                .foregroundColor(.appDarkGray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)

            // ── 5. 구분선 ──
            Rectangle()
                .fill(Color.appGray)
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // ── 6. 키워드 ──
            Text("[keywords]")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)
            
            Text("describe the film")
                .font(.appMicro)
                .foregroundColor(.appDarkGray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 12)

            VStack(spacing: 8) {
                // keyword 1
                HStack(spacing: 8) {
                    Color.clear.frame(width: 24, height: 24)
                    TextField(text: $keywordInput1, prompt: Text(suggested(0).isEmpty ? "summer" : suggested(0)).foregroundColor(.appGray)) { }
                        .font(.appBody)
                        .foregroundColor(.appBlack)
                        .multilineTextAlignment(.center)
                        .focused($keyword1Focused)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 257, height: 26)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .background(Color.appWhite)
                        .frame(width: 289, height: 36)
                        .onChange(of: keywordInput1) { _, _ in updateKeywords() }
                    Button { keyword1Focused = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                            .foregroundColor(.appBlack)
                    }
                    .frame(width: 24, height: 24)
                }

                // keyword 2
                HStack(spacing: 8) {
                    Color.clear.frame(width: 24, height: 24)
                    TextField(text: $keywordInput2, prompt: Text(suggested(1).isEmpty ? "friends" : suggested(1)).foregroundColor(.appGray)) { }
                        .font(.appBody)
                        .foregroundColor(.appBlack)
                        .multilineTextAlignment(.center)
                        .focused($keyword2Focused)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 257, height: 26)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .background(Color.appWhite)
                        .frame(width: 289, height: 36)
                        .onChange(of: keywordInput2) { _, _ in updateKeywords() }
                    Button { keyword2Focused = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                            .foregroundColor(.appBlack)
                    }
                    .frame(width: 24, height: 24)
                }

                // keyword 3
                HStack(spacing: 8) {
                    Color.clear.frame(width: 24, height: 24)
                    TextField(text: $keywordInput3, prompt: Text(suggested(2).isEmpty ? "golden hour" : suggested(2)).foregroundColor(.appGray)) { }
                        .font(.appBody)
                        .foregroundColor(.appBlack)
                        .multilineTextAlignment(.center)
                        .focused($keyword3Focused)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 257, height: 26)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .background(Color.appWhite)
                        .frame(width: 289, height: 36)
                        .onChange(of: keywordInput3) { _, _ in updateKeywords() }
                    Button { keyword3Focused = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                            .foregroundColor(.appBlack)
                    }
                    .frame(width: 24, height: 24)
                }
            }
            .padding(.bottom, 20)

            // ── 7. 구분선 ──
            Rectangle()
                .fill(Color.appGray)
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // ── 8. 사진 개수 ──
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appWhite)
                        .frame(width: 33, height: 29)
                    Text("\(cassetteData.selectedPhotos.count)")
                        .font(.appBody)
                        .foregroundColor(.appBlack)
                }
                Text("photos")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 16)

            // ── 9. 필름 스트립 ──
            GeometryReader { geo in
                ZStack {
                    Image("film")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: 228)
                        .clipped()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cassetteData.selectedPhotos) { photo in
                                BCutImageView(source: photo.imageSource, width: 120, height: 160)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(height: 228)

            Spacer().frame(height: 120)
        }
        }
        .background(Color.appBackground.ignoresSafeArea())

        // ── Next 버튼 고정 ──
        VStack(spacing: 0) {
            Button {
                if cassetteData.name.isEmpty {
                    cassetteData.name = "film \(appState.cassettes.count + 1)"
                }
                updateKeywords()
                startLoading()
            } label: {
                Text("next")
                    .font(.appBody)
                    .foregroundColor(.appWhite)
                    .frame(width: 201, height: 48)
                    .background(Capsule().fill(Color.appDarkGray))
            }
            Spacer().frame(height: 11)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))


        } // 안쪽 ZStack 닫기
        if isLoading {
            CassetteLoadingOverlay(progress: loadingProgress)
        }

        } // 바깥 ZStack 닫기
        .navigationDestination(isPresented: $navigateToDesign) {
            SelectDesignScreen()
                .environmentObject(appState)
                .environmentObject(cassetteData)
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
        .onTapGesture { hideKeyboard() }
        .onAppear { loadKeywords() }
        .alert("Leave without saving?", isPresented: $showExitAlert) {
            Button("leave", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("Your cassette won't be saved.")
        }
    }

    private func startLoading() {
        loadingProgress = 0.0
        isLoading = true
        loadingTask = Task {
            for i in 1...40 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { loadingProgress = Double(i) / 40.0 }
            }
            await MainActor.run {
                isLoading = false
                navigateToDesign = true
            }
        }
    }

    private func loadKeywords() {
        if cassetteData.keywords.count > 0 { keywordInput1 = cassetteData.keywords[0] }
        if cassetteData.keywords.count > 1 { keywordInput2 = cassetteData.keywords[1] }
        if cassetteData.keywords.count > 2 { keywordInput3 = cassetteData.keywords[2] }
    }

    private func updateKeywords() {
        // 빈 칸은 suggestedKeyword로 대체
        let k1 = keywordInput1.trimmingCharacters(in: .whitespaces)
        let k2 = keywordInput2.trimmingCharacters(in: .whitespaces)
        let k3 = keywordInput3.trimmingCharacters(in: .whitespaces)
        cassetteData.keywords = [
            k1.isEmpty ? suggested(0) : k1,
            k2.isEmpty ? suggested(1) : k2,
            k3.isEmpty ? suggested(2) : k3
        ].filter { !$0.isEmpty }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
