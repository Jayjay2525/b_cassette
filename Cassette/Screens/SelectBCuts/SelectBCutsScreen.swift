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
    @State private var isLoadingMore: Bool = false
    @State private var allLoaded: Bool = false
    @State private var showToast: Bool = false
    @State private var navigateToDetail: Bool = false
    @State private var isProcessing: Bool = false
    @State private var processingProgress: Double = 0.0
    @State private var showFilterSheet: Bool = false
    @State private var activeFilter: PhotoFilter = .recent
    private let pageSize: Int = 100

    enum PhotoFilter: String, CaseIterable {
        case recent = "recent"
        case favorites = "favorite"
        case selfies = "selfie"
    }

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

            // ── 2. 메인 영역 (캐러셀 or 그리드) ──
            if isGridMode {
                // ── 그리드 모드 ──
                if assets.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3),
                            spacing: 4
                        ) {
                            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { idx, asset in
                                let selected = isBCutSelected(asset)
                                GridPhotoCell(asset: asset, isSelected: selected)
                                    .onTapGesture { toggleGridSelection(asset) }
                                    .onAppear {
                                        if idx == assets.count - 10 {
                                            loadMorePhotos()
                                        }
                                    }
                            }
                        }
                        .padding(.bottom, 100)

                        if !allLoaded {
                            ProgressView()
                                .padding(.bottom, 120)
                        }
                    }
                    .padding(.horizontal, 24)
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
                            .font(.appBody)
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
        VStack(spacing: 12) {
            let isDisabled = cassetteData.selectedPhotos.count < 5
            Text("\(cassetteData.selectedPhotos.count) / \(AppConstants.maxBCuts)")
                .font(.appBody)
                .foregroundColor(isAtLimit ? .appAccent : .appBlack)
                .frame(width: 92, height: 48)
                .background(Capsule().fill(Color.appBackground))

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

                Button {
                    if isDisabled {
                        withAnimation(.easeIn(duration: 0.2)) { showToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) { showToast = false }
                        }
                    } else {
                        startProcessing()
                    }
                } label: {
                    Text("next")
                        .font(.appBody)
                        .foregroundColor(.appWhite)
                        .frame(width: 201, height: 48)
                        .background(Capsule().fill(isDisabled ? Color.appGray : Color.appDarkGray))
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showFilterSheet.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appWhite)
                            .frame(width: 48, height: 48)
                        Image("button_sort")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 11)

        // 필터 팝업
        if showFilterSheet {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(PhotoFilter.allCases, id: \.self) { filter in
                    Button {
                        applyFilter(filter)
                        withAnimation(.easeInOut(duration: 0.15)) { showFilterSheet = false }
                    } label: {
                        HStack(spacing: 8) {
                            Text(filter.rawValue)
                                .font(.appMicro)
                                .foregroundColor(.appBlack)
                            Spacer()
                            if activeFilter == filter {
                                Image("checkmark_small")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .frame(height: 36)
                    }
                    if filter != PhotoFilter.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 120)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.appWhite))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 24)
            .padding(.bottom, 72)
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomTrailing)))
            .zIndex(998)
        }

        // 토스트
        if showToast {
            Text("select at least 5 images!")
                .font(.appMicro)
                .foregroundColor(.appWhite)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.appDarkGray))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity)
                .zIndex(999)
                .allowsHitTesting(false)
        }
        // 로딩 오버레이
        if isProcessing {
            FilmProcessingView(progress: processingProgress)
                .transition(.opacity)
                .zIndex(1000)
        }
        } // ZStack 닫기
        .navigationDestination(isPresented: $navigateToDetail) {
            SelectDetailScreen()
                .environmentObject(appState)
                .environmentObject(cassetteData)
        }
        .navigationBarHidden(true)
        .onAppear { requestPhotoAccess() }
        .onTapGesture {
            if showFilterSheet { withAnimation(.easeInOut(duration: 0.15)) { showFilterSheet = false } }
        }
        .alert("Leave without saving?", isPresented: $showExitAlert) {
            Button("leave", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("Your cassette won't be saved.")
        }
    }

    // MARK: - Empty / Auth state

    var emptyState: some View {
        VStack(spacing: 12) {
            if authStatus == .denied || authStatus == .restricted {
                Text("photos access denied")
                    .font(.appMicro)
                    .foregroundColor(.appGray)
                Text("enable in Settings → Privacy → Photos")
                    .font(.appMicro)
                    .foregroundColor(.appGray)
                    .multilineTextAlignment(.center)
            } else {
                Text("loading photos...")
                    .font(.appMicro)
                    .foregroundColor(.appGray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Processing

    func startProcessing() {
        withAnimation(.easeIn(duration: 0.2)) { isProcessing = true }
        processingProgress = 0.0

        let photos = cassetteData.selectedPhotos
        cassetteData.assetIDsToDelete = photos.compactMap {
            if case .asset(let id) = $0.imageSource { return id }
            return nil
        }
        let cassetteID = cassetteData.cassetteID
        let total = photos.count
        var savedPhotos: [BCutPhoto] = Array(repeating: photos[0], count: total)
        let group = DispatchGroup()

        // 1. 로컬 저장 (병렬)
        for (i, photo) in photos.enumerated() {
            guard case .asset(let id) = photo.imageSource else {
                savedPhotos[i] = photo
                continue
            }
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = result.firstObject else {
                savedPhotos[i] = photo
                continue
            }
            group.enter()
            appState.saveBCut(asset: asset, cassetteID: cassetteID, isBCut: photo.isBCut) { saved in
                savedPhotos[i] = saved ?? photo
                DispatchQueue.main.async {
                    processingProgress = min(0.7, processingProgress + 0.7 / Double(total))
                }
                group.leave()
            }
        }

        // 2. 로컬 저장 완료 후 Claude API 호출
        group.notify(queue: .main) {
            cassetteData.selectedPhotos = savedPhotos
            processingProgress = 0.7

            // 저장된 파일에서 이미지 로드해서 Claude API에 전달
            let filePhotos = savedPhotos.prefix(50)
            var images: [UIImage] = []
            for photo in filePhotos {
                if case .file(let url) = photo.imageSource,
                   let img = UIImage(contentsOfFile: url.path) {
                    images.append(img)
                }
            }

            Task {
                let keywords = (try? await ClaudeAPIService.extractKeywords(from: images)) ?? []
                await MainActor.run {
                    cassetteData.suggestedKeywords = keywords
                    processingProgress = 1.0
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run {
                    isProcessing = false
                    navigateToDetail = true
                }
            }
        }
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
        loadMorePhotos()
    }

    func loadMorePhotos() {
        guard !isLoadingMore, !allLoaded else { return }
        isLoadingMore = true
        let currentCount = assets.count
        let nextLimit = currentCount + pageSize
        let filter = activeFilter

        DispatchQueue.global(qos: .userInitiated).async {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

            let result: PHFetchResult<PHAsset>
            switch filter {
            case .recent:
                options.fetchLimit = nextLimit
                result = PHAsset.fetchAssets(with: .image, options: options)
            case .favorites:
                options.predicate = NSPredicate(format: "isFavorite == YES")
                options.fetchLimit = nextLimit
                result = PHAsset.fetchAssets(with: .image, options: options)
            case .selfies:
                let selfieAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumSelfPortraits, options: nil)
                if let album = selfieAlbums.firstObject {
                    options.fetchLimit = nextLimit
                    result = PHAsset.fetchAssets(in: album, options: options)
                } else {
                    result = PHFetchResult<PHAsset>()
                }
            }

            var loaded: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in loaded.append(asset) }

            DispatchQueue.main.async {
                assets = loaded
                allLoaded = loaded.count < nextLimit
                isLoadingMore = false
            }
        }
    }

    func applyFilter(_ filter: PhotoFilter) {
        activeFilter = filter
        assets = []
        allLoaded = false
        currentIndex = 0
        loadMorePhotos()
    }
}

// MARK: - Grid Cell

struct GridPhotoCell: View {
    let asset: PHAsset
    let isSelected: Bool

    @State private var image: UIImage? = nil

    var body: some View {
        Color.clear
            .aspectRatio(3/4, contentMode: .fit)
            .overlay(
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.appGray.opacity(0.3)
                    }
                }
            )
            .clipped()
            .contentShape(Rectangle())
            .overlay(isSelected ? Color.black.opacity(0.15) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(Color.appBlack, lineWidth: isSelected ? 1 : 0))
            .overlay(alignment: .topTrailing) {
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
            .overlay(isSelected ? Color.black.opacity(0.15) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(Color.appBlack, lineWidth: isSelected ? 1 : 0))

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

