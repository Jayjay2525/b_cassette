import SwiftUI
import Photos

struct SelectDetailScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert: Bool = false
    @State private var keywordInput: String = ""
    @State private var isEditingName: Bool = false
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var keywordFieldFocused: Bool

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    // 선택된 사진들의 날짜 범위
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
        VStack(spacing: 0) {

            // ── 1. Navbar ──
            HStack {
                Button { dismiss() } label: {
                    Image("button_chevronLeft")
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                }
                Spacer()
                Text("select detail")
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
            .padding(.bottom, 20)

            // ── 2. 이름 수정 TextField ──
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
                    isEditingName = true
                    nameFieldFocused = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.appBlack)
                }
                .frame(width: 24, height: 24)
            }
            .padding(.bottom, 16)

            // ── 3. 날짜 메타데이터 ──
            Text(dateRangeString)
                .font(.cutiveMono(16))
                .foregroundColor(.appDarkGray)
                .padding(.bottom, 16)

            // ── 4. 사진 개수 ──
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.appWhite)
                        .frame(width: 48, height: 48)
                    Text("\(cassetteData.selectedPhotos.count)")
                        .font(.cutiveMono(24))
                        .foregroundColor(.appBlack)
                }
                Text("photos")
                    .font(.cutiveMono(16))
                    .foregroundColor(.appDarkGray)
            }
            .padding(.bottom, 24)

            // ── 5. 필름 스트립 ZStack ──
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
                                FilmPhotoThumb(photo: photo, height: 160)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(height: 228)
            .padding(.bottom,24)

            // ── 6. 키워드 ──
            VStack(spacing: 12) {
                Text("keywords\n(optional)")
                    .font(.cutiveMono(16))
                    .foregroundColor(.appBlack)
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    ForEach(cassetteData.keywords, id: \.self) { kw in
                        HStack {
                            Spacer()
                            Text(kw)
                                .font(.cutiveMono(16))
                                .foregroundColor(.appBlack)
                            Spacer()
                        }
                        .frame(maxWidth: 180)
                        .frame(height: 42)
                        .background(Capsule().fill(Color.appGray.opacity(0.5)))
                    }

                    if cassetteData.keywords.count < 3 {
                        HStack {
                            TextField("add keyword", text: $keywordInput)
                                .font(.cutiveMono(16))
                                .foregroundColor(.appBlack)
                                .multilineTextAlignment(.center)
                                .focused($keywordFieldFocused)
                                .onSubmit { addKeyword() }

                            if !keywordInput.isEmpty {
                                Button { addKeyword() } label: {
                                    Image(systemName: "return")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.appBlack)
                                }
                                .padding(.trailing, 16)
                            }
                        }
                        .frame(maxWidth: 180)
                        .frame(height: 42)
                        .background(
                            Capsule()
                                .strokeBorder(Color.appGray, lineWidth: 1)
                        )
                    }
                }
            }

            Spacer()
        }
        .background(Color.appBackground.ignoresSafeArea())

        // ── 7. Next 버튼 (ZStack 최상단 고정) ──
        VStack(spacing: 0) {
            NavigationLink {
                SelectDesignScreen()
                    .environmentObject(appState)
                    .environmentObject(cassetteData)
            } label: {
                Text("next")
                    .font(.cutiveMono(18))
                    .foregroundColor(.appWhite)
                    .frame(width: 183, height: 48)
                    .background(Capsule().fill(Color(hex: "#555555")))
                    .opacity(cassetteData.name.isEmpty ? 0.4 : 1.0)
            }
            .disabled(cassetteData.name.isEmpty)
            Spacer().frame(height: 41)
        }
        .frame(maxWidth: .infinity)
        .background(Color.appBackground.ignoresSafeArea(edges: .bottom))
        } // ZStack 닫기
        .navigationBarHidden(true)
        .onTapGesture { hideKeyboard() }
        .alert("discard cassette?", isPresented: $showExitAlert) {
            Button("discard", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("your selections will not be saved.")
        }
    }

    private func addKeyword() {
        let kw = keywordInput.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty, !cassetteData.keywords.contains(kw), cassetteData.keywords.count < 3 else { return }
        cassetteData.keywords.append(kw)
        keywordInput = ""
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - 필름 스트립 썸네일

struct FilmPhotoThumb: View {
    let photo: BCutPhoto
    let height: CGFloat

    @State private var image: UIImage? = nil

    var width: CGFloat { height * 0.75 }

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.appGray.opacity(0.3)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear { loadImage() }
    }

    private func loadImage() {
        if case .asset(let id) = photo.imageSource {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = result.firstObject else { return }
            let size = CGSize(width: width * 3, height: height * 3)
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
                if let img { DispatchQueue.main.async { image = img } }
            }
        } else if case .file(let url) = photo.imageSource,
                  let img = UIImage(contentsOfFile: url.path) {
            image = img
        }
    }
}
