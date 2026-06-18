import SwiftUI

struct SelectDetailScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert: Bool = false
    @State private var navigateToDesign: Bool = false
    @State private var keywordInput1: String = ""
    @State private var keywordInput2: String = ""
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var keyword1Focused: Bool
    @FocusState private var keyword2Focused: Bool

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
        ZStack(alignment: .bottom) {
        ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {

            // ── 1. Navbar ──
            HStack {
                Button { dismiss() } label: {
                    Image("button_chevronLeft")
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                }
                Spacer()
                Text("make a film")
                    .font(.cutiveMono(20))
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
            Text("title")
                .font(.cutiveMono(16))
                .foregroundColor(.appBlack)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // ── 3. 이름 입력 ──
            HStack(spacing: 12) {
                Color.clear.frame(width: 24, height: 24)

                TextField(text: $cassetteData.name, prompt: Text("cassette \(appState.cassettes.count + 1)").foregroundColor(.appGray)) { }
                    .font(.cutiveMono(20))
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
            .padding(.bottom, 16)

            // ── 4. 날짜 ──
            Text(dateRangeString)
                .font(.cutiveMono(16))
                .foregroundColor(.appDarkGray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)

            // ── 5. 구분선 ──
            Rectangle()
                .fill(Color(hex: "#B4B4B4"))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // ── 6. 키워드 ──
            Text("keyword")
                .font(.cutiveMono(16))
                .foregroundColor(.appBlack)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)

            VStack(spacing: 12) {
                // keyword 1
                HStack(spacing: 12) {
                    Color.clear.frame(width: 24, height: 24)
                    TextField(text: $keywordInput1, prompt: Text("summer").foregroundColor(.appGray)) { }
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .multilineTextAlignment(.center)
                        .focused($keyword1Focused)
                        .lineLimit(1)
                        .frame(width: 220, height: 36)
                        .background(Capsule().fill(Color.appWhite))
                        .onChange(of: keywordInput1) { _, val in updateKeywords() }
                    Button { keyword1Focused = true } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                            .foregroundColor(.appBlack)
                    }
                    .frame(width: 24, height: 24)
                }

                // keyword 2
                HStack(spacing: 12) {
                    Color.clear.frame(width: 24, height: 24)
                    TextField(text: $keywordInput2, prompt: Text("friends").foregroundColor(.appGray)) { }
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .multilineTextAlignment(.center)
                        .focused($keyword2Focused)
                        .lineLimit(1)
                        .frame(width: 220, height: 36)
                        .background(Capsule().fill(Color.appWhite))
                        .onChange(of: keywordInput2) { _, val in updateKeywords() }
                    Button { keyword2Focused = true } label: {
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
                .fill(Color(hex: "#B4B4B4"))
                .frame(height: 1)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            // ── 8. 사진 개수 ──
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appWhite)
                        .frame(width: 33, height: 29)
                    Text("\(cassetteData.selectedPhotos.count)")
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                }
                Text("photos")
                    .font(.cutiveMono(16))
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
                    cassetteData.name = "cassette \(appState.cassettes.count + 1)"
                }
                navigateToDesign = true
            } label: {
                Text("next")
                    .font(.cutiveMono(18))
                    .foregroundColor(.appWhite)
                    .frame(width: 183, height: 48)
                    .background(Capsule().fill(Color(hex: "#555555")))
            }
            .navigationDestination(isPresented: $navigateToDesign) {
                SelectDesignScreen()
                    .environmentObject(appState)
                    .environmentObject(cassetteData)
            }
            Spacer().frame(height: 41)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
        } // ZStack 닫기
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

    private func loadKeywords() {
        if cassetteData.keywords.count > 0 { keywordInput1 = cassetteData.keywords[0] }
        if cassetteData.keywords.count > 1 { keywordInput2 = cassetteData.keywords[1] }
    }

    private func updateKeywords() {
        var kws: [String] = []
        let k1 = keywordInput1.trimmingCharacters(in: .whitespaces)
        let k2 = keywordInput2.trimmingCharacters(in: .whitespaces)
        if !k1.isEmpty { kws.append(k1) }
        if !k2.isEmpty { kws.append(k2) }
        cassetteData.keywords = kws
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
