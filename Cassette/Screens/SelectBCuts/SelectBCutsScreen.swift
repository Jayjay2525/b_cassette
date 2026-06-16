import SwiftUI
import Photos

struct SelectBCutsScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert: Bool = false
    @State private var isGridMode: Bool = false
    @State private var assets: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var dragX: CGFloat = 0
    @State private var authStatus: PHAuthorizationStatus = .notDetermined

    private let mainWidth: CGFloat = 297
    private let sideWidth: CGFloat = 259
    private let cardSpacing: CGFloat = 12

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    var currentAsset: PHAsset? {
        guard !assets.isEmpty, currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    var currentDateString: String {
        guard let date = currentAsset?.creationDate else { return "--" }
        return fmt.string(from: date)
    }

    var isAtLimit: Bool {
        cassetteData.selectedPhotos.count >= AppConstants.maxBCuts
    }

    var body: some View {
        ZStack(alignment: .bottom) {
        VStack(spacing: 0) {

            // ── 1. Navbar ──
            HStack {
                Color.clear.frame(width: 24, height: 24)
                Spacer()
                Text("select b-cuts")
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

            // ── 2. 메인 영역 (캐러셀 or 그리드) ──
            if isGridMode {
                // ── 그리드 모드 ──
                if assets.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3),
                            spacing: 2
                        ) {
                            ForEach(assets, id: \.localIdentifier) { asset in
                                let selected = isBCutSelected(asset)
                                GridPhotoCell(asset: asset, isSelected: selected)
                                    .onTapGesture { toggleGridSelection(asset) }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                }
            } else {
                // ── 캐러셀 모드 ──
                if assets.isEmpty {
                    emptyState
                } else {
                    GeometryReader { geo in
                        let cardHeight = mainWidth * (343.0 / 259.0)
                        let topPadding = max(0, (geo.size.height - cardHeight) / 2 - 50)
                        let offset = carouselOffset(centerX: geo.size.width / 2) + dragX

                        HStack(spacing: cardSpacing) {
                            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { idx, asset in
                                let isMain = idx == currentIndex
                                BCutPhotoCard(
                                    asset: asset,
                                    width: isMain ? mainWidth : sideWidth,
                                    verticalOffset: 0,
                                    isSelected: isBCutSelected(asset)
                                )
                                .onTapGesture {
                                    if isMain { toggleGridSelection(asset) }
                                }
                            }
                        }
                        .offset(x: offset, y: topPadding)
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onChanged { v in
                                    if abs(v.translation.width) > abs(v.translation.height) {
                                        dragX = v.translation.width
                                    }
                                }
                                .onEnded { v in
                                    let threshold: CGFloat = 50
                                    if v.translation.width < -threshold && currentIndex < assets.count - 1 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { currentIndex += 1; dragX = 0 }
                                    } else if v.translation.width > threshold && currentIndex > 0 {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { currentIndex -= 1; dragX = 0 }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragX = 0 }
                                    }
                                }
                        )

                        // ── 날짜 ──
                        Text(currentDateString)
                            .font(.cutiveMono(16))
                            .foregroundColor(.appDarkGray)
                            .frame(maxWidth: .infinity)
                            .offset(y: topPadding + cardHeight + 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())

        // ── 4. Control Bar (ZStack 최상단 고정) ──
        HStack {
            Button { withAnimation(.easeInOut(duration: 0.2)) { isGridMode.toggle() } } label: {
                ZStack {
                    Circle()
                        .fill(Color.appWhite)
                        .frame(width: 48, height: 48)
                    Image(isGridMode ? "button_oneLayout" : "button_gridLayout")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }

            Spacer()

            NavigationLink {
                SelectDetailScreen()
                    .environmentObject(appState)
                    .environmentObject(cassetteData)
            } label: {
                Text("next")
                    .font(.cutiveMono(18))
                    .foregroundColor(.appWhite)
                    .frame(width: 183, height: 48)
                    .background(Capsule().fill(Color(hex: "#555555")))
                    .opacity(cassetteData.selectedPhotos.count < 5 ? 0.4 : 1.0)
            }
            .disabled(cassetteData.selectedPhotos.count < 5)

            Spacer()

            Text("\(cassetteData.selectedPhotos.count)/\(AppConstants.maxBCuts)")
                .font(.cutiveMono(13))
                .foregroundColor(isAtLimit ? .appAccent : .appBlack)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.appWhite))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 41)
        .overlay(alignment: .top) {
            if cassetteData.selectedPhotos.count < 5 {
                Text("select at least 5 images!")
                    .font(.cutiveMono(14))
                    .foregroundColor(Color(hex: "#FF0000"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .offset(y: -26)
            }
        }
        } // ZStack 닫기
        .navigationBarHidden(true)
        .onAppear { requestPhotoAccess() }
        .alert("discard cassette?", isPresented: $showExitAlert) {
            Button("discard", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("your selections will not be saved.")
        }
    }

    // MARK: - Empty / Auth state

    var emptyState: some View {
        VStack(spacing: 12) {
            if authStatus == .denied || authStatus == .restricted {
                Text("photos access denied")
                    .font(.cutiveMono(14))
                    .foregroundColor(.appGray)
                Text("enable in Settings → Privacy → Photos")
                    .font(.cutiveMono(12))
                    .foregroundColor(.appGray)
                    .multilineTextAlignment(.center)
            } else {
                Text("loading photos...")
                    .font(.cutiveMono(14))
                    .foregroundColor(.appGray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    func carouselOffset(centerX: CGFloat) -> CGFloat {
        var offset = centerX - mainWidth / 2
        for _ in 0..<currentIndex {
            offset -= (sideWidth + cardSpacing)
        }
        return offset
    }

    func isBCutSelected(_ asset: PHAsset) -> Bool {
        cassetteData.selectedPhotos.contains(where: { photo in
            if case .asset(let id) = photo.imageSource { return id == asset.localIdentifier }
            return false
        })
    }

    func toggleGridSelection(_ asset: PHAsset) {
        if isBCutSelected(asset) {
            cassetteData.selectedPhotos.removeAll {
                if case .asset(let id) = $0.imageSource { return id == asset.localIdentifier }
                return false
            }
        } else if !isAtLimit {
            let photo = BCutPhoto(
                id: UUID(),
                imageSource: .asset(asset.localIdentifier),
                isBCut: true,
                takenAt: asset.creationDate ?? Date()
            )
            cassetteData.selectedPhotos.append(photo)
        }
    }


    func requestPhotoAccess() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited {
            loadPhotos()
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                authStatus = status
                if status == .authorized || status == .limited {
                    loadPhotos()
                }
            }
        }
    }

    func loadPhotos() {
        guard assets.isEmpty else { return }  // 이미 로드됐으면 스킵
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 200
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var loaded: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in loaded.append(asset) }
        DispatchQueue.main.async { assets = loaded }
    }
}

// MARK: - Grid Cell

struct GridPhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool

    @State private var image: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.appGray.opacity(0.3)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                if isSelected {
                    ZStack {
                        Circle().fill(Color.appBlack).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(6)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .aspectRatio(3/4, contentMode: .fit)
        .onAppear { loadImage() }
    }

    func loadImage() {
        let size = CGSize(width: 300, height: 300)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
            if let img { DispatchQueue.main.async { image = img } }
        }
    }
}

// MARK: - Photo Card

struct BCutPhotoCard: View {
    let asset: PHAsset
    let width: CGFloat
    let verticalOffset: CGFloat
    let isSelected: Bool

    @State private var image: UIImage? = nil

    var cardHeight: CGFloat { width * (343.0 / 259.0) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.appGray.opacity(0.3)
                }
            }
            .frame(width: width, height: cardHeight)
            .clipped()

            if isSelected {
                ZStack {
                    Circle().fill(Color.appBlack).frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(8)
            }
        }
        .offset(y: verticalOffset)
        .onAppear { loadImage() }
    }

    func loadImage() {
        let size = CGSize(width: width * 3, height: cardHeight * 3)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { img, _ in
            if let img { DispatchQueue.main.async { image = img } }
        }
    }
}
