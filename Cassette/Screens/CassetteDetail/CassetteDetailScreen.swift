import SwiftUI
import Combine
import Photos
import AVFoundation

struct CassetteDetailScreen: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State var cassette: CassetteModel

    init(cassette: CassetteModel) {
        _cassette = State(initialValue: cassette)
    }

    // MARK: - State
    @State private var isPlaying: Bool = false
    @State private var isScrubbing: Bool = false
    @State private var cassettePressed: Bool = false
    @State private var showKeywords: Bool = false
    @State private var playProgress: Double = 0.0
    @State private var showDeleteAlert: Bool = false
    @State private var showRevertAlert: Bool = false
    @State private var player: AVAudioPlayer? = nil
    @State private var filmManualOffset: CGFloat = 0
    @State private var filmDragTranslation: CGFloat = 0

    // MARK: - Timer
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // MARK: - Constants
    private var totalDuration: Double { player?.duration ?? 0 }
    private let filmPhotoWidth: CGFloat = 120
    private let filmPhotoHeight: CGFloat = 160
    private let filmStripHeight: CGFloat = 228

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    private var dateRangeText: String {
        guard let range = cassette.photoDateRange else { return "--" }
        return "\(fmt.string(from: range.oldest)) – \(fmt.string(from: range.latest))"
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // 1. Navigation Bar
                navBar

                // 2. Date info
                Text(dateRangeText)
                    .font(.appMicro)
                    .foregroundColor(.appDarkGray)
                    .padding(.top, 16)

                // 3. Photo count info
                Text("\(cassette.photos.count) photos")
                    .font(.appMicro)
                    .foregroundColor(.appDarkGray)
                    .padding(.top, 8)

                // 4. Cassette ZStack
                cassetteZStack
                    .padding(.top, 16)

                // 5. Music progress indicator
                musicIndicator
                    .padding(.top, 8)
                    .padding(.horizontal, 24)

                // 6. Play / Pause button
                playButton
                    .padding(.top, -8)

                // 7. Film strip
                filmStrip
                    .padding(.top, 32)

                // 8. Days left
                Text(cassette.isExpired ? "expired" : "\(cassette.daysLeft) days left")
                    .font(.appBody)
                    .foregroundColor(cassette.isExpired ? .appDarkGray : .appAccent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)

                // 9. Action buttons
                actionButtons
                    .padding(.top, 32)
                    .padding(.horizontal, 24)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onChange(of: appState.cassettes) {
            if let updated = appState.cassettes.first(where: { $0.id == cassette.id }) {
                cassette = updated
            }
        }
        .onReceive(timer) { _ in
            guard isPlaying, !isScrubbing, let player else { return }
            if player.isPlaying {
                withAnimation(.linear(duration: 0.05)) {
                    playProgress = player.currentTime / player.duration
                }
            } else {
                isPlaying = false
                playProgress = 0.0
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear {
            player?.stop()
            isPlaying = false
        }
        .alert("restore photos", isPresented: $showRevertAlert) {
            Button("open photos") {
                if let url = URL(string: "photos-redirect://") {
                    UIApplication.shared.open(url)
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("photos deleted within 30 days can be recovered.\ngo to Photos → Recently Deleted to restore them.")
        }
        .alert("Delete Cassette", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                appState.deleteCassette(id: cassette.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(cassette.name)\" and all its photos will be permanently deleted. This cannot be undone.")
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var navBar: some View {
        HStack(spacing: 24) {
            Button { dismiss() } label: {
                Image("button_chevronLeft")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }

            Text(cassette.name)
                .font(.cutiveMono(17))
                .foregroundColor(.appBlack)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 251, height: 36, alignment: .center)
                .background(Color.appWhite)

            Button { /* TODO: share */ } label: {
                Image("button_share")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
        //.padding(.horizontal, 0)
        .padding(.top, 12)
    }

    private var cassetteZStack: some View {
        ZStack {
            CassetteImageView(cassette: cassette, width: 320)

            // 키워드 오버레이
            if showKeywords && !cassette.keywords.isEmpty {
                Color.appBackground.opacity(0.8)
                    .frame(width: 320)
                    .overlay(
                        FlowLayout(spacing: 10, keywords: cassette.keywords)
                    )
                    .transition(.opacity)
            }
        }
        .scaleEffect(cassettePressed ? 0.9 : 1.0)
        .onTapGesture {
            // 이미 보이면 닫기
            if showKeywords {
                withAnimation(.easeInOut(duration: 0.2)) { showKeywords = false }
                return
            }
            // 눌리는 인터랙션 → 키워드 표시
            withAnimation(.easeInOut(duration: 0.12)) { cassettePressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    cassettePressed = false
                }
                withAnimation(.easeInOut(duration: 0.2)) { showKeywords = true }
            }
        }
    }

    // 338px @3x → 112.67pt / 7px @3x → 2.33pt
    private let indicatorWidth: CGFloat = 338
    private let indicatorHeight: CGFloat = 7

    private var musicIndicator: some View {
        VStack(spacing: 0) {
            // Progress bar
            ZStack(alignment: .leading) {
                // Layer 1: 배경
                Capsule()
                    .fill(Color.appGray)
                    .frame(width: indicatorWidth, height: indicatorHeight)

                // Layer 2: 진행 표시 (흰색 RoundedRectangle)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white)
                    .frame(
                        width: max(0, indicatorWidth * CGFloat(playProgress)),
                        height: indicatorHeight
                    )
            }
            .frame(width: indicatorWidth, height: indicatorHeight)
            // 터치 영역 확장
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let ratio = max(0, min(1, Double(v.location.x / indicatorWidth)))
                        playProgress = ratio
                        isScrubbing = true
                        player?.pause()
                    }
                    .onEnded { v in
                        let ratio = max(0, min(1, Double(v.location.x / indicatorWidth)))
                        playProgress = ratio
                        if let player {
                            player.currentTime = ratio * player.duration
                            if isPlaying {
                                player.play()
                            }
                        }
                        isScrubbing = false
                    }
            )

            // Time labels
            HStack {
                Text(timeString(playProgress * totalDuration))
                    .font(.appMicro)
                    .foregroundColor(.appBlack)
                Spacer()
                Text(timeString(totalDuration))
                    .font(.appMicro)
                    .foregroundColor(.appBlack)
            }
            .frame(width: indicatorWidth)
        }
    }

    private var playButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isPlaying {
                    player?.pause()
                    isPlaying = false
                } else {
                    player?.play()
                    isPlaying = true
                    withAnimation(.easeInOut(duration: 0.4)) {
                        filmManualOffset = 0
                        filmDragTranslation = 0
                    }
                }
            }
        } label: {
            Image(isPlaying ? "button_stop" : "button_play")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }

    private func setupPlayer() {
        let url = resolveTrackURL()
        guard let url else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } catch {
            print("audio setup error: \(error)")
        }
    }

    private func resolveTrackURL() -> URL? {
        let trackName = cassette.trackName
        // Documents에 저장된 파일 우선 확인 (special cassette)
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cassettes/\(cassette.id.uuidString)/\(trackName)")
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        // Bundle에서 찾기 (일반 cassette)
        let components = trackName.components(separatedBy: ".")
        guard components.count == 2 else { return nil }
        return Bundle.main.url(forResource: components[0], withExtension: components[1])
    }

    // MARK: - Film Strip

    /// ZStack 중앙 정렬을 보정한 HStack offset 계산
    /// ZStack 안에서 width=W인 HStack의 left edge  = screenWidth/2 - W/2 + offset
    ///                                  right edge = screenWidth/2 + W/2 + offset
    /// - progress=0: left edge  = 0            (첫 사진이 화면 왼쪽 끝)
    /// - progress=1: right edge = screenWidth  (마지막 사진이 화면 오른쪽 끝에 딱 맞게)
    private func filmOffset(screenWidth: CGFloat, totalFilmWidth: CGFloat) -> CGFloat {
        let startOffset = totalFilmWidth / 2 - screenWidth / 2   // left edge  → 0
        let endOffset   = screenWidth / 2 - totalFilmWidth / 2   // right edge → screenWidth
        return startOffset + (endOffset - startOffset) * CGFloat(playProgress)
    }

    private var filmStrip: some View {
        let bCuts = cassette.bCuts
        let photoWidth: CGFloat = filmPhotoWidth
        let photoHeight: CGFloat = filmPhotoHeight
        let gap: CGFloat = 4
        let totalFilmWidth = (photoWidth + gap) * CGFloat(bCuts.count)

        return GeometryReader { geo in
            ZStack {
                // Layer 1: film 배경 이미지 (화면 너비에 꽉 맞게)
                Image("film")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: filmStripHeight)
                    .clipped()

                // Layer 2: B-cut 사진들 (playProgress에 따라 오른→왼 이동)
                if bCuts.isEmpty {
                    Text("no b-cuts")
                        .font(.appMicro)
                        .foregroundColor(.appWhite)
                } else {
                    let autoOffset = filmOffset(screenWidth: geo.size.width, totalFilmWidth: totalFilmWidth)
                    let startOffset = totalFilmWidth / 2 - geo.size.width / 2
                    let endOffset   = geo.size.width / 2 - totalFilmWidth / 2
                    let minManual = endOffset - autoOffset
                    let maxManual = startOffset - autoOffset
                    let clampedManual = min(maxManual, max(minManual, filmManualOffset + filmDragTranslation))
                    HStack(spacing: gap) {
                        ForEach(bCuts) { photo in
                            BCutImageView(source: photo.imageSource, width: photoWidth, height: photoHeight)
                        }
                    }
                    .offset(x: autoOffset + (isPlaying ? 0 : clampedManual))
                    .animation(isPlaying ? .linear(duration: 0.05) : nil, value: playProgress)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { v in
                                if !isPlaying {
                                    filmDragTranslation = v.translation.width
                                }
                            }
                            .onEnded { v in
                                if !isPlaying {
                                    filmManualOffset = min(maxManual, max(minManual, filmManualOffset + v.translation.width))
                                    filmDragTranslation = 0
                                }
                            }
                    )
                }
            }
            .frame(width: geo.size.width, height: filmStripHeight)
        }
        .frame(height: filmStripHeight)
        .clipped()
    }

    private var actionButtons: some View {
        HStack(spacing: 13) {
            // Revert
            Spacer()
            Button {
                showRevertAlert = true
            } label: {
                Text("revert")
                    .font(.appBody)
                    .foregroundColor(.appWhite)
                    .frame(maxWidth: 160)
                    .frame(height: 52)
                    .background(Color.appBlack)
                    .clipShape(Capsule())
            }

            // Delete
            Button {
                showDeleteAlert = true
            } label: {
                Text("delete")
                    .font(.appBody)
                    .foregroundColor(.appWhite)
                    .frame(maxWidth: 160)
                    .frame(height: 52)
                    .background(Color.appDarkGray)
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }
}

// MARK: - Keyword Flow Layout

struct FlowLayout: View {
    let spacing: CGFloat
    let keywords: [String]

    var body: some View {
        ZStack {
            VStack(spacing: spacing) {
                ForEach(chunked(keywords, size: 2), id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.self) { keyword in
                            Text(keyword)
                                .font(.appBody)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Color.appLightAccent))
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func chunked(_ array: [String], size: Int) -> [[String]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
}

// MARK: - Preview

#Preview {
    CassetteDetailScreen(cassette: MockData.cassettes[0])
        .environmentObject(AppState())
}
