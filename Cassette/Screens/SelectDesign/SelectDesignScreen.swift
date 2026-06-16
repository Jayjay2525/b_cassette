import SwiftUI
import Photos

struct SelectDesignScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert = false
    @State private var isSaving = false
    @State private var originalIdentifiers: [String] = []
    @State private var currentIndex: Int = 0
    @State private var dragY: CGFloat = 0

    private let designs = CassetteDesign.allCases
    private let itemSpacing: CGFloat = 150   // 아이템 간 수직 간격
    private let dragDamping:  CGFloat = 0.45 // 드래그 감도 (낮을수록 둔감)
    private let mainWidth:    CGFloat = 345

    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f
    }()

    var dateRangeString: String {
        let dates = cassetteData.selectedPhotos.map { $0.takenAt }
        guard let earliest = dates.min(), let latest = dates.max() else { return "--" }
        if fmt.string(from: earliest) == fmt.string(from: latest) { return fmt.string(from: earliest) }
        return "\(fmt.string(from: earliest))  —  \(fmt.string(from: latest))"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Navbar ──
                HStack {
                    Button { dismiss() } label: {
                        Image("button_chevronLeft")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Text("select design")
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

                // ── 카세트 정보 (이름 / 날짜 / 사진 수) ──
                VStack(spacing: 12) {
                    // 이름
                    Text(cassetteData.name.isEmpty ? "untitled" : cassetteData.name)
                        .font(.cutiveMono(20))
                        .foregroundColor(.appBlack)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 257, height: 26)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .background(Color.appWhite)
                        .frame(width: 289, height: 36)

                    // 날짜
                    Text(dateRangeString)
                        .font(.cutiveMono(16))
                        .foregroundColor(.appDarkGray)

                    // 사진 수
                    Text("\(cassetteData.selectedPhotos.count) photos")
                        .font(.cutiveMono(16))
                        .foregroundColor(.appDarkGray)
                }
                .padding(.bottom, 16)

                // ── 캐러셀 ──
                GeometryReader { geo in
                    ZStack {
                        ForEach(0..<designs.count, id: \.self) { idx in
                            carouselItem(idx: idx, in: geo)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .gesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { v in
                                dragY = v.translation.height
                            }
                            .onEnded { v in
                                let velocity = v.predictedEndTranslation.height
                                let combined = (dragY + velocity * 0.3) * dragDamping

                                // 몇 칸 이동할지 결정
                                let steps = -Int((combined / itemSpacing).rounded())
                                let newIndex = max(0, min(designs.count - 1, currentIndex + steps))

                                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                    currentIndex = newIndex
                                    dragY = 0
                                }
                            }
                    )
                }

                Color.clear.frame(height: 100)
            }

            // ── Done 버튼 고정 ──
            VStack(spacing: 0) {
                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    cassetteData.design = designs[currentIndex]
                    originalIdentifiers = cassetteData.selectedPhotos.compactMap {
                        if case .asset(let id) = $0.imageSource { return id }
                        return nil
                    }
                    savePhotosLocally {
                        let newCassette = cassetteData.buildCassette()
                        appState.addCassette(newCassette)
                        isSaving = false
                        let ids = originalIdentifiers
                        cassetteData.shouldDismiss = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                            var assets: [PHAsset] = []
                            result.enumerateObjects { asset, _, _ in assets.append(asset) }
                            appState.deleteFromPhotos(assets: assets) { _ in }
                        }
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appWhite))
                        } else {
                            Text("done")
                                .font(.cutiveMono(18))
                                .foregroundColor(.appWhite)
                        }
                    }
                    .frame(width: 183, height: 48)
                    .background(Capsule().fill(Color(hex: "#555555")))
                }
                Spacer().frame(height: 41)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationBarHidden(true)
        .onAppear {
            if let idx = designs.firstIndex(of: cassetteData.design) {
                currentIndex = idx
            }
        }
        .alert("discard cassette?", isPresented: $showExitAlert) {
            Button("discard", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("your selections will not be saved.")
        }
    }

    // MARK: - 로컬 저장

    private func savePhotosLocally(completion: @escaping () -> Void) {
        let photos = cassetteData.selectedPhotos
        let cassetteID = cassetteData.cassetteID
        var savedPhotos: [BCutPhoto] = Array(repeating: photos[0], count: photos.count)
        let group = DispatchGroup()

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
                group.leave()
            }
        }

        group.notify(queue: .main) {
            cassetteData.selectedPhotos = savedPhotos
            completion()
        }
    }

    // MARK: - 각 아이템 뷰

    @ViewBuilder
    private func carouselItem(idx: Int, in geo: GeometryProxy) -> some View {
        let relPos   = CGFloat(idx - currentIndex) - (dragY * dragDamping) / itemSpacing
        let distance = abs(relPos)

        if distance > 2.5 {
            Color.clear.frame(width: 0, height: 0)
        } else {
            let scale   = max(0.5, 1.0 - distance * 0.18)
            let opacity = max(0.0, 1.0 - distance * 0.60)
            let yOffset = relPos * itemSpacing

            Image(designs[idx].imageName)
                .resizable()
                .scaledToFit()
                .frame(width: mainWidth)
                .scaleEffect(scale)
                .opacity(opacity)
                .offset(y: yOffset)
                .zIndex(-distance)
        }
    }
}
