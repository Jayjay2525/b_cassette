import SwiftUI
import AVFoundation
import Photos

// MARK: - CassetteShareScreen

struct CassetteShareScreen: View {
    let cassette: CassetteModel
    @Environment(\.dismiss) private var dismiss

    // 배경 색상 선택
    @State private var selectedColorHex: String = "FFB3CD"

    // 오디오
    @State private var player: AVAudioPlayer? = nil
    @State private var isPlaying = false
    @State private var musicDuration: Double = 0
    @State private var musicStartTime: Double = 0  // 0.0 ~ 1.0 (비율)

    // 내보내기
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var showShareSheet = false
    @State private var exportedURL: URL? = nil
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""

    // 카드 그리드 애니메이션
    @State private var gridScrollOffset: CGFloat = 0
    @State private var gridDragStartOffset: CGFloat = 0
    @State private var animationTimer: Timer? = nil

    // 재생 중 진행 표시
    @State private var playProgress: CGFloat = 0
    @State private var progressTimer: Timer? = nil

    // 바 드래그 시작 시점의 musicStartTime 캡처
    @State private var barDragStartTime: Double? = nil

    private let cardWidth: CGFloat = 270
    private let cardHeight: CGFloat = 433
    // 음악 윈도우 rect
    private let windowW: CGFloat = 180
    private let windowH: CGFloat = 40

    // 배경 색상 팔레트 (카세트 색상 + 흑백)
    private let palette: [(hex: String, color: Color)] = [
        ("FFB3CD", Color(hex: "FFB3CD")),
        ("FFB389", Color(hex: "FFB389")),
        ("FF9696", Color(hex: "FF9696")),
        ("FFFFFF", Color(hex: "FFFFFF")),
        ("000000", Color.black),
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── 공유 카드 미리보기 ──
            shareCard
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .padding(.top, 44)

            Spacer().frame(height: 12)

            // ── 음악 컨트롤 ──
            musicControl
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 4)

            // ── 색상 팔레트 ──
            HStack(spacing: 12) {
                ForEach(palette, id: \.hex) { item in
                    let isSelected = selectedColorHex == item.hex
                    let strokeColor: Color = item.hex == "000000" ? .white : .appBlack
                    Circle()
                        .fill(item.color)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().strokeBorder(strokeColor, lineWidth: isSelected ? 1 : 0)
                        )
                        .onTapGesture { selectedColorHex = item.hex }
                }
                // 커스텀 색상 (color picker)
                let paletteHexes = palette.map(\.hex)
                let customSelected = !paletteHexes.contains(selectedColorHex)
                ColorPickerCircle(selectedHex: $selectedColorHex, isCustomSelected: customSelected)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            // ── 하단 버튼 ──
            HStack(spacing: 32) {
                exportButton(icon: "button_video", label: "save video") {
                    exportVideo(shareToInstagram: false)
                }
                exportButton(icon: "button_instagram", label: "instagram") {
                    exportVideo(shareToInstagram: true)
                }
            }

            Spacer().frame(height: 32)
        }
        .background(Color.appBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .overlay {
            if isExporting {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView(value: exportProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                        .tint(.white)
                    Text("rendering...")
                        .font(.appBody)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.8)))
            }
        }
        .onAppear { setupAudio() }
        .onDisappear { stopPlayback() }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .alert(saveAlertMessage, isPresented: $showSaveAlert) {
            Button("ok", role: .cancel) {}
        }
    }

    // MARK: - 공유 카드

    private var shareCard: some View {
        // 카드 고정 사이즈: 270×433
        // 셀 너비: 118, 여백: 6
        let cellW: CGFloat = 118
        let cellH: CGFloat = cellW * 4 / 3   // 3:4 비율 → 약 157pt
        let gap: CGFloat = 6
        let bCuts = cassette.bCuts
        let columns = [GridItem(.fixed(cellW), spacing: gap), GridItem(.fixed(cellW), spacing: gap)]

        return ZStack(alignment: .center) {
            // Z1: 배경색 (palette에서 선택한 색)
            Color(hex: selectedColorHex)
                .frame(width: cardWidth, height: cardHeight)

            // Z2: 이미지 그리드 — 6pt padding, 셀 118×157pt, gap 6pt
            let rows = CGFloat((bCuts.count + 1) / 2)
            let totalGridH = rows * cellH + (rows - 1) * gap + gap * 2
            let maxScrollable = max(0, totalGridH - cardHeight)
            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(Array((bCuts.isEmpty ? [nil] : bCuts.map { Optional($0) }).enumerated()), id: \.offset) { _, photo in
                    Group {
                        if let photo {
                            SharePhotoCell(photo: photo)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: cellW, height: cellH)
                    .clipped()
                }
            }
            .padding(gap)
            .frame(width: cardWidth, height: totalGridH, alignment: .top)
            .offset(y: -gridScrollOffset)
            .animation(.linear(duration: 0.05), value: gridScrollOffset)
            .frame(width: cardWidth, height: cardHeight, alignment: .top)
            .clipped()
            .gesture(
                DragGesture()
                    .onChanged { v in
                        guard !isPlaying else { return }
                        let newOffset = gridDragStartOffset - v.translation.height
                        gridScrollOffset = min(maxScrollable, max(0, newOffset))
                    }
                    .onEnded { _ in
                        gridDragStartOffset = gridScrollOffset
                    }
            )

            // Z3: 검정 75% 불투명 rounded rect — 색상 고정, palette 무관
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))
                .frame(width: 204, height: 195)

            // Z4: 카세트 콘텐츠 (Z3 위에) — CassetteImageView로 detail과 동일하게
            VStack(spacing: 4) {
                Text("b_cassette")
                    .font(.appMicro)
                    .foregroundColor(.white.opacity(0.6))

                CassetteImageView(cassette: cassette, width: 156)
                    .frame(width: 156)

                Text(cassette.name)
                    .font(.appBody)
                    .foregroundColor(.white)

                if let range = cassette.photoDateRange {
                    Text("\(dateFmt.string(from: range.oldest)) — \(dateFmt.string(from: range.latest))")
                        .font(.appMicro)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 204, height: 195)
        }
    }

    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    // MARK: - 음악 컨트롤

    private var musicControl: some View {
        let barTotalW: CGFloat = max(windowW * 2, CGFloat(musicDuration / 15.0) * windowW)
        let maxBarOffset: CGFloat = barTotalW - windowW
        let barShift: CGFloat = CGFloat(musicStartTime) * maxBarOffset
        let startSec = musicStartTime * max(0, musicDuration - 15)
        let endSec = startSec + 15.0

        return VStack(spacing: 12) {
            Button { togglePlayback() } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.appBlack)
                    .frame(width: 32, height: 32)
            }

            ZStack {
                // 뒤에 깔리는 바 (드래그 가능)
                GeometryReader { geo in
                    Capsule()
                        .fill(Color.appGray.opacity(0.4))
                        .frame(width: barTotalW, height: 6)
                        .offset(x: (geo.size.width - windowW) / 2 - barShift)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    if barDragStartTime == nil { barDragStartTime = musicStartTime }
                                    let startShift = CGFloat(barDragStartTime ?? musicStartTime) * maxBarOffset
                                    let newShift = min(maxBarOffset, max(0, startShift - v.translation.width))
                                    musicStartTime = Double(newShift / max(maxBarOffset, 1))
                                    if isPlaying { seekToStart(); playProgress = 0 }
                                }
                                .onEnded { _ in barDragStartTime = nil }
                        )
                }

                // stroke rect + 재생 progress (rect 영역 안에서만 표시)
                ZStack(alignment: .leading) {
                    // 재생 progress fill — 바와 같은 높이 capsule
                    Capsule()
                        .fill(Color.white)
                        .frame(width: windowW * playProgress, height: 6)

                    // stroke rect 테두리
                    Image("rect_round_area")
                        .resizable()
                        .frame(width: windowW, height: windowH)
                }
                .frame(width: windowW, height: windowH)
                .clipped()
                .allowsHitTesting(false)
            }
            .frame(height: windowH)

            Text("\(formattedTime(startSec))  ~  \(formattedTime(endSec))")
                .font(.appMicro)
                .foregroundColor(.appDarkGray)
        }
    }

    // MARK: - 오디오

    private func setupAudio() {
        guard let url = resolveTrackURL() else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            musicDuration = player?.duration ?? 0
        } catch {}
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            let startSeconds = musicStartTime * max(0, musicDuration - 15)
            player?.currentTime = startSeconds
            player?.play()
            isPlaying = true
            playProgress = 0
            startProgressTimer()
            startGridAnimation()
        }
    }

    private func seekToStart() {
        let startSeconds = musicStartTime * max(0, musicDuration - 15)
        player?.currentTime = startSeconds
        player?.play()
    }

    private func stopPlayback() {
        player?.stop()
        isPlaying = false
        playProgress = 0
        stopProgressTimer()
        stopGridAnimation()
        gridDragStartOffset = gridScrollOffset
    }

    private func startGridAnimation() {
        let bCuts = cassette.bCuts
        guard bCuts.count > 0, musicDuration > 0 else { return }

        let cellW: CGFloat = 118
        let cellH: CGFloat = cellW * 4 / 3
        let gap: CGFloat = 6
        let rows = CGFloat((bCuts.count + 1) / 2)
        let totalGridH = rows * cellH + (rows - 1) * gap + gap * 2
        let maxScrollable = max(0, totalGridH - cardHeight)

        let startOffset = gridScrollOffset
        // 15초 동안 스크롤할 거리 = 전체 그리드 높이 * (15 / 음악 전체 길이)
        let scrollDistance = totalGridH * CGFloat(15.0 / musicDuration)
        let endOffset = min(maxScrollable, startOffset + scrollDistance)

        // 시작점이 이미 끝에 닿아있으면 애니메이션 없음
        guard startOffset < maxScrollable else { return }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isPlaying else { return }
            gridScrollOffset = startOffset + (endOffset - startOffset) * playProgress
        }
    }

    private func stopGridAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isPlaying else { return }
            let elapsed = (player?.currentTime ?? 0) - musicStartTime * max(0, musicDuration - 15)
            playProgress = CGFloat(min(1, max(0, elapsed / 15.0)))
            if playProgress >= 1 {
                // 15초 구간 끝 → 시작점으로 돌아가서 반복
                seekToStart()
                playProgress = 0
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }


    private func resolveTrackURL() -> URL? {
        let trackName = cassette.trackName
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cassettes/\(cassette.id.uuidString)/\(trackName)")
        if FileManager.default.fileExists(atPath: localURL.path) { return localURL }
        let parts = trackName.components(separatedBy: ".")
        guard parts.count == 2 else { return nil }
        return Bundle.main.url(forResource: parts[0], withExtension: parts[1])
    }

    // MARK: - 비디오 렌더링 & 공유

    private func exportVideo(shareToInstagram: Bool) {
        isExporting = true
        exportProgress = 0

        Task {
            do {
                let url = try await ShareVideoRenderer.render(
                    cassette: cassette,
                    backgroundColorHex: selectedColorHex,
                    musicStartRatio: musicDuration > 0 ? (musicStartTime * max(0, musicDuration - 15)) / musicDuration : 0,
                    gridStartOffset: gridScrollOffset * (1080 / 270),
                    onProgress: { p in
                        await MainActor.run { exportProgress = p }
                    }
                )
                await MainActor.run {
                    isExporting = false
                    exportedURL = url
                    if shareToInstagram {
                        shareToInstagramStories(videoURL: url)
                    } else {
                        saveVideoToPhotos(url: url)
                    }
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    saveAlertMessage = "export failed: \(error.localizedDescription)"
                    showSaveAlert = true
                }
            }
        }
    }

    private func shareToInstagramStories(videoURL: URL) {
        // Instagram Stories URL scheme
        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundVideo": (try? Data(contentsOf: videoURL)) ?? Data()
        ]
        UIPasteboard.general.setItems([pasteboardItems], options: [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ])
        if let url = URL(string: "instagram-stories://share?source_application=b_cassette") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // 인스타 미설치시 일반 공유
                showShareSheet = true
            }
        }
    }

    private func saveVideoToPhotos(url: URL) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            DispatchQueue.main.async {
                saveAlertMessage = success ? "video saved to photos!" : "save failed"
                showSaveAlert = true
            }
        }
    }

    // MARK: - 헬퍼

    private func formattedTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func textColor(for hex: String) -> Color {
        // 밝은 배경이면 검정, 어두우면 흰색
        let darkHexes = ["000000"]
        return darkHexes.contains(hex.uppercased()) ? Color.white : Color.black
    }

    @ViewBuilder
    private func exportButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appWhite)
                        .frame(width: 48, height: 48)
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                Text(label)
                    .font(.appMicro)
                    .foregroundColor(.appBlack)
            }
        }
    }
}

// MARK: - ColorPickerCircle

private struct ColorPickerCircle: View {
    @Binding var selectedHex: String
    var isCustomSelected: Bool
    @State private var pickedColor: Color = .purple

    var body: some View {
        // ColorPicker를 베이스에 두고 시각 레이어를 allowsHitTesting(false)로 위에 덮음
        // → 터치가 시각 레이어를 통과해 ColorPicker에 도달
        ColorPicker("", selection: $pickedColor, supportsOpacity: false)
            .labelsHidden()
            .onChange(of: pickedColor) { _, c in
                selectedHex = c.toHex() ?? "000000"
            }
            .frame(width: 36, height: 36)
            .overlay {
                ZStack {
                    if isCustomSelected {
                        Circle().fill(Color(hex: selectedHex))
                    } else {
                        Circle().fill(
                            AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red],
                                            center: .center)
                        )
                    }
                    Circle().strokeBorder(
                        isCustomSelected ? strokeColor(for: selectedHex) : Color.clear,
                        lineWidth: 1
                    )
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isCustomSelected ? strokeColor(for: selectedHex) : .white)
                }
                .allowsHitTesting(false)
            }
    }

    private func strokeColor(for hex: String) -> Color {
        guard let c = UIColor(hex: hex) else { return .black }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance < 0.4 ? .white : .black
    }
}

// MARK: - SharePhotoCell

private struct SharePhotoCell: View {
    let photo: BCutPhoto
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .clipped()
        .onAppear { loadImage() }
    }

    private func loadImage() {
        switch photo.imageSource {
        case .file(let url):
            if let img = UIImage(contentsOfFile: url.path) { image = img }
        case .asset(let id):
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = result.firstObject else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 300, height: 400), contentMode: .aspectFill, options: opts) { img, _ in
                if let img { DispatchQueue.main.async { image = img } }
            }
        case .bundleAsset(let name):
            image = UIImage(named: name)
        }
    }
}

// MARK: - ActivityViewController

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Color / UIColor extensions

private extension Color {
    func toHex() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: CGFloat((val >> 16) & 0xFF) / 255,
            green: CGFloat((val >> 8) & 0xFF) / 255,
            blue: CGFloat(val & 0xFF) / 255,
            alpha: 1
        )
    }
}
