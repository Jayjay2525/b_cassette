import SwiftUI
import Photos

struct SelectBCutsScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var assets: [PHAsset] = []
    @State private var currentIndex: Int = 0
    @State private var dragX: CGFloat = 0
    @State private var flyUpOffset: CGFloat = 0
    @State private var isFlying: Bool = false
    @State private var authStatus: PHAuthorizationStatus = .notDetermined
    @State private var lockedDirection: GestureDirection = .none

    enum GestureDirection { case none, horizontal, vertical }

    private let mainWidth: CGFloat = 297
    private let sideWidth: CGFloat = 259
    private let cardSpacing: CGFloat = 12
    private let swipeUpThreshold: CGFloat = 80

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
        VStack(spacing: 0) {

            // ── 1. Navbar ──
            HStack {
                Color.clear.frame(width: 24, height: 24)
                Spacer()
                Text("select b-cuts")
                    .font(.cutiveMono(20))
                    .foregroundColor(.appBlack)
                Spacer()
                Button { cassetteData.shouldDismiss = true } label: {
                    Image("button_x")
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // ── 2. Photo ZStack ──
            ZStack {
                Image("arrow_bcut")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48)
                    .offset(y: -80)

                if assets.isEmpty {
                    emptyState
                } else {
                    GeometryReader { geo in
                        let cardHeight = mainWidth * 1.3
                        let topPadding = (geo.size.height - cardHeight) / 2
                        let offset = carouselOffset(centerX: geo.size.width / 2) + dragX
                        HStack(spacing: cardSpacing) {
                            ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { idx, asset in
                                let isMain = idx == currentIndex
                                BCutPhotoCard(
                                    asset: asset,
                                    width: isMain ? mainWidth : sideWidth,
                                    verticalOffset: isMain ? flyUpOffset : 0,
                                    isSelected: false
                                )
                            }
                        }
                        .offset(x: offset, y: max(0, topPadding))
                        .gesture(
                            DragGesture(minimumDistance: 12)
                                .onChanged { v in
                                    guard !isFlying else { return }

                                    if lockedDirection == .none {
                                        if abs(v.translation.height) > abs(v.translation.width) {
                                            lockedDirection = v.translation.height < 0 ? .vertical : .none
                                        } else {
                                            lockedDirection = .horizontal
                                        }
                                    }

                                    switch lockedDirection {
                                    case .vertical:
                                        flyUpOffset = min(0, v.translation.height)
                                    case .horizontal:
                                        dragX = v.translation.width
                                    case .none:
                                        break
                                    }
                                }
                                .onEnded { v in
                                    defer { lockedDirection = .none }
                                    guard !isFlying else {
                                        flyUpOffset = 0; dragX = 0; return
                                    }

                                    switch lockedDirection {
                                    case .vertical:
                                        if v.translation.height < -CGFloat(swipeUpThreshold) && !isAtLimit {
                                            selectCurrentAsBCut()
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                flyUpOffset = 0
                                            }
                                        }
                                    case .horizontal:
                                        flyUpOffset = 0
                                        let threshold: CGFloat = 50
                                        if v.translation.width < -threshold && currentIndex < assets.count - 1 {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                currentIndex += 1; dragX = 0
                                            }
                                        } else if v.translation.width > threshold && currentIndex > 0 {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                currentIndex -= 1; dragX = 0
                                            }
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                dragX = 0
                                            }
                                        }
                                    case .none:
                                        flyUpOffset = 0; dragX = 0
                                    }
                                }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── 3. 날짜 ──
            Text(currentDateString)
                .font(.cutiveMono(14))
                .foregroundColor(.appGray)
                .padding(.vertical, 16)

            // ── 4. Control Bar ──
            HStack {
                Button { } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appWhite)
                            .frame(width: 48, height: 48)
                        Image("button_gridLayout")
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
                        .opacity(cassetteData.selectedPhotos.isEmpty ? 0.4 : 1.0)
                }
                .disabled(cassetteData.selectedPhotos.isEmpty)

                Spacer()

                Text("\(cassetteData.selectedPhotos.count)/\(AppConstants.maxBCuts)")
                    .font(.cutiveMono(13))
                    .foregroundColor(isAtLimit ? .appAccent : .appBlack)
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(isAtLimit ? Color.appAccent : Color.appGray, lineWidth: 1))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { requestPhotoAccess() }
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

    func selectCurrentAsBCut() {
        guard let asset = currentAsset, !isAtLimit, !isFlying else { return }

        let indexToRemove = currentIndex
        isFlying = true

        withAnimation(.easeIn(duration: 0.25)) {
            flyUpOffset = -800
        } completion: {
            let photo = BCutPhoto(
                id: UUID(),
                imageSource: .asset(asset.localIdentifier),
                isBCut: true,
                takenAt: asset.creationDate ?? Date()
            )
            cassetteData.selectedPhotos.append(photo)

            var removeTx = Transaction()
            removeTx.disablesAnimations = true
            withTransaction(removeTx) {
                if indexToRemove < assets.count {
                    assets.remove(at: indexToRemove)
                }
                if currentIndex >= assets.count && currentIndex > 0 {
                    currentIndex -= 1
                }
            }

            var tx = Transaction()
            tx.disablesAnimations = true
            withTransaction(tx) { flyUpOffset = 0 }

            isFlying = false
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
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 200
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var loaded: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in loaded.append(asset) }
        DispatchQueue.main.async { assets = loaded }
    }
}

// MARK: - Photo Card

struct BCutPhotoCard: View {
    let asset: PHAsset
    let width: CGFloat
    let verticalOffset: CGFloat
    let isSelected: Bool

    @State private var image: UIImage? = nil

    var cardHeight: CGFloat { width * 1.3 }

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
