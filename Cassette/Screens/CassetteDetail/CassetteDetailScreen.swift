import SwiftUI
import Combine

struct CassetteDetailScreen: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let cassette: CassetteModel

    // MARK: - State
    @State private var isPlaying: Bool = false
    @State private var playProgress: Double = 0.0
    @State private var showDeleteAlert: Bool = false

    // MARK: - Timer
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    // MARK: - Constants
    private let totalDuration: Double = 199  // 3:19
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
                    .font(.cutiveMono(15))
                    .foregroundColor(.appDarkGray)
                    .padding(.top, 16)

                // 3. Photo count info
                Text("\(cassette.photos.count) photos")
                    .font(.cutiveMono(15))
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
                    .font(.cutiveMono(16))
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
        .onReceive(timer) { _ in
            guard isPlaying else { return }
            let step = 0.05 / totalDuration
            if playProgress < 1.0 {
                withAnimation(.linear(duration: 0.05)) {
                    playProgress = min(1.0, playProgress + step)
                }
            } else {
                isPlaying = false
                playProgress = 0.0
            }
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

    private var navBar: some View {
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
            // 추후: roll+film 레이어 (아래)
            // 현재: cassette design 이미지만
            Image(cassette.design.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 320)
        }
    }

    // 338px @3x → 112.67pt / 7px @3x → 2.33pt
    private let indicatorWidth: CGFloat = 338
    private let indicatorHeight: CGFloat = 7

    private var musicIndicator: some View {
        VStack(spacing: 0) {
            // Progress bar
            ZStack(alignment: .leading) {
                // Layer 1: 배경 이미지
                Image("music_indicator_background")
                    .resizable()
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
                        playProgress = max(0, min(1, Double(v.location.x / indicatorWidth)))
                    }
            )

            // Time labels
            HStack {
                Text(timeString(playProgress * totalDuration))
                    .font(.cutiveMono(12))
                    .foregroundColor(.appBlack)
                Spacer()
                Text(timeString(totalDuration))
                    .font(.cutiveMono(12))
                    .foregroundColor(.appBlack)
            }
            .frame(width: indicatorWidth)
        }
    }

    private var playButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isPlaying.toggle()
            }
        } label: {
            Image(isPlaying ? "button_stop" : "button_play")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
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
                        .font(.cutiveMono(13))
                        .foregroundColor(.appWhite)
                } else {
                    HStack(spacing: gap) {
                        ForEach(bCuts) { photo in
                            Color.appGray
                                .frame(width: photoWidth, height: photoHeight)
                        }
                    }
                    .offset(x: filmOffset(screenWidth: geo.size.width, totalFilmWidth: totalFilmWidth))
                    .animation(.linear(duration: 0.05), value: playProgress)
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
                // TODO: revert B-cuts
            } label: {
                Text("revert")
                    .font(.cutiveMono(18))
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
                    .font(.cutiveMono(18))
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

// MARK: - Preview

#Preview {
    CassetteDetailScreen(cassette: MockData.cassettes[0])
        .environmentObject(AppState())
}
