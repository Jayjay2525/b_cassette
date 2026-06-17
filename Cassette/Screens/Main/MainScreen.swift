import SwiftUI

// MARK: - Panel State
enum InfoPanelMode {
    case overall    // 전체 통계
    case cassette   // 선택된 카세트 정보
}

struct MainScreen: View {
    @EnvironmentObject var appState: AppState
    @State private var panelMode: InfoPanelMode = .overall
    @State private var panelVisible: Bool = true
    @State private var circleActive: Bool = false
    @State private var rotationIndex: Int = 2
    @State private var dragOffset: CGFloat = 0
    @State private var swipeRightOffset: CGFloat = 0
    @State private var selectedCassette: CassetteModel? = nil
    @State private var navigateToDetail = false
    @State private var showNewCassette = false
    @State private var showDeleteAlert = false

    let dragThreshold: CGFloat = 160
    let swipeRightThreshold: CGFloat = 120

    var dragProgress: CGFloat {
        max(-1, min(1, dragOffset / dragThreshold))
    }

    // 0...1, swipe right 진행도 (opacity용 — 더 넓은 범위로 천천히 감소)
    var swipeRightProgress: CGFloat {
        max(0, min(1, swipeRightOffset / 320))
    }

    var mainCassette: CassetteModel? {
        guard !appState.cassettes.isEmpty else { return nil }
        return appState.cassettes[rotationIndex % appState.cassettes.count]
    }

    func onCircleTap() {
        guard dragOffset == 0 else { return }       // 드래그 중엔 탭 무시
        guard !appState.cassettes.isEmpty else { return }  // 카세트 없으면 무시
        selectedCassette = mainCassette
        withAnimation(.easeInOut(duration: 0.25)) {
            circleActive = true
            panelMode = .cassette
            panelVisible = true
        }
    }

    func onMenuTap() {
        withAnimation(.easeInOut(duration: 0.25)) {
            circleActive = false
            panelMode = .overall
            panelVisible = true
        }
    }

    func commitSwipe() {
        let count = appState.cassettes.count
        guard count >= 2 else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
            return
        }
        if dragOffset > dragThreshold / 2 {
            rotationIndex = (rotationIndex - 1 + count) % count
        } else if dragOffset < -dragThreshold / 2 {
            rotationIndex = (rotationIndex + 1) % count
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragOffset = 0
        }
        if circleActive { selectedCassette = mainCassette }
    }

    func onSwipeRightChanged(_ offset: CGFloat) {
        guard circleActive else { return }
        swipeRightOffset = max(0, offset)
    }

    func onSwipeRightEnded(_ offset: CGFloat) {
        guard circleActive else { swipeRightOffset = 0; return }
        if swipeRightOffset >= swipeRightThreshold {
            // 화면 밖으로 날리고 이동
            withAnimation(.easeIn(duration: 0.2)) {
                swipeRightOffset = 400
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedCassette = mainCassette
                navigateToDetail = true
                swipeRightOffset = 0
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                swipeRightOffset = 0
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {

                    // Layer 1: Background
                    (circleActive ? Color.appGray : Color.appBackground)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.25), value: circleActive)
                        .onTapGesture { onMenuTap() }

                    // Layer 2: Circle (탭 + 실시간 드래그)
                    CircleLayer(
                        geo: geo,
                        active: circleActive,
                        onTap: onCircleTap,
                        onDragChanged: { offset in
            guard appState.cassettes.count >= 2 else { return }
            dragOffset = offset
        },
                        onDragEnded: { _ in commitSwipe() }
                    )
                    .opacity(1 - swipeRightProgress)

                    // Layer 3: Cassettes
                    CassetteStackLayer(
                        cassettes: appState.cassettes,
                        geo: geo,
                        circleActive: circleActive,
                        rotationIndex: rotationIndex,
                        dragProgress: dragProgress,
                        swipeRightOffset: swipeRightOffset,
                        swipeRightProgress: swipeRightProgress,
                        onTap: { cassette in
                            if circleActive {
                                selectedCassette = cassette
                                navigateToDetail = true
                            } else {
                                onCircleTap()
                            }
                        },
                        onSwipeRightChanged: onSwipeRightChanged,
                        onSwipeRightEnded: onSwipeRightEnded,
                        onAddTap: { showNewCassette = true }
                    )

                    // Layer 4: UI
                    UILayer(
                        appState: appState,
                        panelVisible: $panelVisible,
                        panelMode: panelMode,
                        mainCassette: circleActive ? (selectedCassette ?? mainCassette) : mainCassette,
                        circleActive: circleActive,
                        onMenuTap: onMenuTap,
                        onAddTap: { showNewCassette = true },
                        onDeleteCassette: { showDeleteAlert = true }
                    )
                    .opacity((1 - swipeRightProgress) * (circleActive ? (1 - abs(dragProgress) * 0.7) : 1))
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .onChange(of: appState.cassettes.count) { oldCount, count in
                if count == 0 {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        circleActive = false
                        panelMode = .overall
                        selectedCassette = nil
                    }
                } else if count > oldCount, let newest = appState.cassettes.last {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedCassette = newest
                        circleActive = true
                        panelMode = .cassette
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToDetail) {
                if let cassette = selectedCassette {
                    CassetteDetailScreen(cassette: cassette)
                }
            }
            .fullScreenCover(isPresented: $showNewCassette) {
                NewCassetteScreen()
                    .environmentObject(appState)
            }
            .alert("delete cassette?", isPresented: $showDeleteAlert) {
                Button("delete", role: .destructive) {
                    if let cassette = selectedCassette {
                        appState.deleteCassette(id: cassette.id)
                    }
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("This cassette will be permanently deleted. This action can't be undone.")
            }
        }
    }
}

// MARK: - Layer 1: Circle

struct CircleLayer: View {
    let geo: GeometryProxy
    let active: Bool
    let onTap: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat) -> Void

    var body: some View {
        Circle()
            .fill(active ? Color.appBackground : Color.appGray)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .frame(width: 728, height: 728)
            .position(x: -27, y: geo.size.height / 2)
            .animation(.easeInOut(duration: 0.25), value: active)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        onDragChanged(value.translation.height)
                    }
                    .onEnded { value in
                        onDragEnded(value.translation.height)
                    }
            )
            .onTapGesture { onTap() }
    }
}

// MARK: - Layer 2: Cassettes

struct CassetteSlot {
    let x: CGFloat
    let yFromMid: CGFloat   // geo.size.height/2 기준 offset
    let rotation: Double
    let zIndex: Double
}

let cassetteSlots: [CassetteSlot] = [
    CassetteSlot(x: 116,  yFromMid: 0,    rotation: 0,   zIndex: 1),   // slot 0: main
    CassetteSlot(x: 65,   yFromMid: -100, rotation: -15, zIndex: 0),   // slot 1
    CassetteSlot(x: 0,    yFromMid: -180, rotation: -45, zIndex: -1),  // slot 2
    CassetteSlot(x: 65,   yFromMid: 120,  rotation: 15,  zIndex: 2),   // slot 3
    CassetteSlot(x: 0,    yFromMid: 180,  rotation: 45,  zIndex: 3),   // slot 4
]

// 가상 슬롯: 슬롯 2 바깥(위)과 슬롯 4 바깥(아래) — 호의 자연스러운 연장선
let slotVirtual0 = CassetteSlot(x: -20, yFromMid: -260, rotation: -60, zIndex: -1)  // 1번 바깥 위
let slotVirtual6 = CassetteSlot(x: -20, yFromMid:  260, rotation:  60, zIndex:  3)  // 5번 바깥 아래

// drag down(+): 각 슬롯의 목적지
let nextSlotDown: [Int: CassetteSlot] = [
    0: cassetteSlots[3],  // main → 4번
    1: cassetteSlots[0],  // 2번  → main
    2: cassetteSlots[1],  // 1번  → 2번
    3: cassetteSlots[4],  // 4번  → 5번
    4: slotVirtual6,      // 5번  → 가상6 (퇴장)
]
// drag up(-): 각 슬롯의 목적지
let nextSlotUp: [Int: CassetteSlot] = [
    0: cassetteSlots[1],  // main → 2번
    1: cassetteSlots[2],  // 2번  → 1번
    2: slotVirtual0,      // 1번  → 가상0 (퇴장)
    3: cassetteSlots[0],  // 4번  → main
    4: cassetteSlots[3],  // 5번  → 4번
]

func lerpSlot(_ a: CassetteSlot, _ b: CassetteSlot, t: CGFloat) -> CassetteSlot {
    CassetteSlot(
        x:          a.x          + (b.x          - a.x)          * t,
        yFromMid:   a.yFromMid   + (b.yFromMid   - a.yFromMid)   * t,
        rotation:   a.rotation   + (b.rotation   - a.rotation)   * Double(t),
        zIndex:     a.zIndex
    )
}

struct CassetteStackLayer: View {
    let cassettes: [CassetteModel]
    let geo: GeometryProxy
    let circleActive: Bool
    let rotationIndex: Int
    let dragProgress: CGFloat
    let swipeRightOffset: CGFloat
    let swipeRightProgress: CGFloat
    let onTap: (CassetteModel) -> Void
    let onSwipeRightChanged: (CGFloat) -> Void
    let onSwipeRightEnded: (CGFloat) -> Void
    let onAddTap: () -> Void

    // 슬롯 우선순위: main → 아래 → 더아래 → 위 → 더위
    let slotPriority = [0, 3, 4, 1, 2]

    var body: some View {
        let count = cassettes.count
        let arrowWidth: CGFloat = 345
        let t = abs(dragProgress)
        let goingDown = dragProgress > 0
        let mainSlot = cassetteSlots[0]

        ZStack {
            // ── 0개: placeholder ──
            if count == 0 {
                Image("placeholder_cassette")
                    .resizable().scaledToFill()
                    .frame(width: 345, height: 222)
                    .scaleEffect(0.8)
                    .position(x: mainSlot.x, y: geo.size.height / 2 + mainSlot.yFromMid)
                    .onTapGesture { onAddTap() }
                    .zIndex(1)

            // ── 1~4개: 카세트 수만큼 슬롯 사용 ──
            } else if count < 5 {
                ForEach(Array(cassettes.enumerated()), id: \.element.id) { i, cassette in
                    let rel = (i - rotationIndex + count) % count
                    let slotIndex = slotPriority[rel]
                    let currentSlot = cassetteSlots[slotIndex]

                    // drag 시 target
                    let targetRel = goingDown
                        ? (rel + 1) % count
                        : (rel - 1 + count) % count
                    let targetSlot = cassetteSlots[slotPriority[targetRel]]

                    // "긴 점프" 감지 (wrap-around): 이동 거리가 크면 fade out
                    let dy = abs(targetSlot.yFromMid - currentSlot.yFromMid)
                    let isWrapAround = dy > 250
                    let slot = isWrapAround ? currentSlot : lerpSlot(currentSlot, targetSlot, t: t)
                    let wrapOpacity = isWrapAround ? Double(max(0, 1 - t * 2)) : 1.0
                    let isMain = slotIndex == 0

                    Image(cassette.design.imageName)
                        .resizable().scaledToFill()
                        .frame(width: 345, height: 222)
                        .scaleEffect(isMain && circleActive ? 0.9 : 0.8)
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 4, y: 6)
                        .rotationEffect(.degrees(slot.rotation))
                        .position(
                            x: slot.x + (isMain ? swipeRightOffset : 0),
                            y: geo.size.height / 2 + slot.yFromMid
                        )
                        .opacity((isMain ? Double(cassette.printProgress) : Double(cassette.printProgress) * Double(1 - swipeRightProgress)) * wrapOpacity)
                        .zIndex(slot.zIndex)
                        .gesture(isMain ? DragGesture(minimumDistance: 10)
                            .onChanged { v in
                                if abs(v.translation.width) > abs(v.translation.height) {
                                    onSwipeRightChanged(v.translation.width)
                                }
                            }
                            .onEnded { v in onSwipeRightEnded(v.translation.width) }
                        : nil)
                        .onTapGesture { if isMain { onTap(cassette) } }
                        .allowsHitTesting(isMain)

                    if isMain {
                        Image("arrow_cassette")
                            .resizable().scaledToFit()
                            .frame(width: arrowWidth)
                            .scaleEffect(1.05)
                            .position(x: geo.size.width / 2 - 5, y: geo.size.height / 2)
                            .opacity(circleActive ? 1 : 0)
                            .animation(.easeInOut(duration: 0.25), value: circleActive)
                            .zIndex(0)
                    }
                }

            // ── 5개+: 기존 로직 ──
            } else {
                ForEach(Array(cassettes.enumerated()), id: \.element.id) { i, cassette in
                    let rel = (i - rotationIndex + count) % count

                    let currentSlotIndex: Int? = {
                        switch rel {
                        case 0:         return 0
                        case 1:         return 3
                        case 2:         return 4
                        case count - 1: return 1
                        case count - 2: return 2
                        case count - 3: return goingDown && t > 0 ? -10 : nil
                        case 3:         return !goingDown && t > 0 ? -20 : nil
                        default:        return nil
                        }
                    }()

                    if let csi = currentSlotIndex {
                        if csi == -10 || csi == -20 {
                            let (from, to): (CassetteSlot, CassetteSlot) = csi == -10
                                ? (slotVirtual0, cassetteSlots[2])
                                : (slotVirtual6, cassetteSlots[4])
                            let interpolated = lerpSlot(from, to, t: t)
                            Image(cassette.design.imageName)
                                .resizable().scaledToFill()
                                .frame(width: 345, height: 222)
                                .scaleEffect(0.8)
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 4, y: 6)
                                .rotationEffect(.degrees(interpolated.rotation))
                                .position(x: interpolated.x, y: geo.size.height / 2 + interpolated.yFromMid)
                                .opacity(Double(t) * Double(cassette.printProgress))
                                .zIndex(interpolated.zIndex)
                        } else {
                            let currentSlot = cassetteSlots[csi]
                            let targetSlot  = goingDown
                                ? (nextSlotDown[csi] ?? currentSlot)
                                : (nextSlotUp[csi]   ?? currentSlot)
                            let slot = lerpSlot(currentSlot, targetSlot, t: t)
                            let isMain = csi == 0

                            Image(cassette.design.imageName)
                                .resizable().scaledToFill()
                                .frame(width: 345, height: 222)
                                .scaleEffect(isMain && circleActive ? 0.9 : 0.8)
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 4, y: 6)
                                .rotationEffect(.degrees(slot.rotation))
                                .position(
                                    x: slot.x + (isMain ? swipeRightOffset : 0),
                                    y: geo.size.height / 2 + slot.yFromMid
                                )
                                .opacity(isMain ? Double(cassette.printProgress) : Double(cassette.printProgress) * Double(1 - swipeRightProgress))
                                .zIndex(slot.zIndex)
                                .gesture(isMain ? DragGesture(minimumDistance: 10)
                                    .onChanged { v in
                                        if abs(v.translation.width) > abs(v.translation.height) {
                                            onSwipeRightChanged(v.translation.width)
                                        }
                                    }
                                    .onEnded { v in onSwipeRightEnded(v.translation.width) }
                                : nil)
                                .onTapGesture { if isMain { onTap(cassette) } }
                                .allowsHitTesting(isMain)

                            if isMain {
                                Image("arrow_cassette")
                                    .resizable().scaledToFit()
                                    .frame(width: arrowWidth)
                                    .position(x: geo.size.width / 2 - 5, y: geo.size.height / 2)
                                    .opacity(circleActive ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.25), value: circleActive)
                                    .zIndex(0)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Layer 3: UI

struct UILayer: View {
    let appState: AppState
    @Binding var panelVisible: Bool
    let panelMode: InfoPanelMode
    let mainCassette: CassetteModel?
    let circleActive: Bool
    let onMenuTap: () -> Void
    let onAddTap: () -> Void
    var onDeleteCassette: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // 우측 상단 버튼들
            VStack(alignment: .trailing, spacing: 30) {
                Button {
                    onAddTap()
                } label: {
                    Image("button_plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(appState.isFull ? 0.3 : 1.0)
                }
                .disabled(appState.isFull)

                Button {
                    onMenuTap()
                } label: {
                    Image("button_menu")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .opacity(appState.cassettes.isEmpty ? 0.3 : 1.0)
                }
                .disabled(appState.cassettes.isEmpty)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 66)
            .padding(.trailing, 24)

            // pin (overall 상태) + pin_main (circle active 상태) + pin_0cassette (empty 상태)
            GeometryReader { geo in
                let isEmpty = appState.cassettes.isEmpty
                let pinTop: CGFloat = 164
                let lineEnd: CGFloat = geo.size.height - 180 - geo.safeAreaInsets.bottom
                let lineHeight = max(1, lineEnd - pinTop - 6)

                // pin_0cassette: 카세트 0개일 때
                // bottom-right = placeholder 우상단 (x:254, y:geo/2-89)
                Image("pin_0cassette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 89)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, geo.size.width - 330)
                    .padding(.bottom, geo.size.height / 2 + 105)
                    .opacity(isEmpty ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: isEmpty)

                // pin: overall일 때 (카세트 있을 때만)
                if geo.size.height > 200 {
                    VStack(spacing: 0) {
                        Circle()
                            .frame(width: 6, height: 6)
                            .foregroundColor(.appBlack)
                        Rectangle()
                            .frame(width: 1, height: lineHeight)
                            .foregroundColor(.appBlack)
                    }
                    .frame(width: 6)
                    .position(x: geo.size.width - 28, y: pinTop + (lineHeight + 6) / 2)
                    .opacity(!circleActive && panelVisible && !isEmpty ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: circleActive)
                    .animation(.easeInOut(duration: 0.25), value: isEmpty)
                }

                // pin_main: circle active일 때, info panel 바로 위
                let pinMainHeight: CGFloat = 162
                let pinMainLineHeight = max(1, pinMainHeight - 6)

                if geo.size.height > 200 {
                    VStack(spacing: 0) {
                        Circle()
                            .frame(width: 6, height: 6)
                            .foregroundColor(.appBlack)
                        Rectangle()
                            .frame(width: 1, height: pinMainLineHeight)
                            .foregroundColor(.appBlack)
                    }
                    .frame(width: 6)
                    .position(x: geo.size.width / 2 + 30, y: lineEnd - pinMainHeight / 2)
                    .opacity(circleActive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: circleActive)
                }
            }

            // 하단 정보 패널 + 액션 버튼
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    if panelMode == .cassette {
                        Button("delete") { onDeleteCassette?() }
                            .font(.cutiveMono(18))
                            .foregroundColor(.appAccent)
                    } else if appState.cassettes.isEmpty {
                        Button("help") {
                            let email = "lapaelp@gmail.com"
                            let subject = "B_Cassette Help"
                            let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                            if let url = URL(string: urlString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.cutiveMono(18))
                        .foregroundColor(.appDarkGray)
                    }
                }
                .padding(.leading, 24)
                .padding(.trailing, 28)
                .padding(.bottom, 8)
                .opacity(panelVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: panelVisible)

                BottomInfoPanel(
                    cassettes: appState.cassettes,
                    mainCassette: mainCassette,
                    mode: panelMode,
                    visible: panelVisible
                )
            }
        }
    }
}

// MARK: - Bottom Info Panel

struct BottomInfoPanel: View {
    let cassettes: [CassetteModel]
    let mainCassette: CassetteModel?
    let mode: InfoPanelMode
    let visible: Bool

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd"
        return f
    }()

    private var totalPhotos: Int {
        cassettes.reduce(0) { $0 + $1.photos.count }
    }

    private var overallDateRange: String {
        let allDates = cassettes.flatMap { $0.photos.map { $0.takenAt } }
        guard let oldest = allDates.min(), let latest = allDates.max() else { return "--" }
        return "\(fmt.string(from: oldest)) - \(fmt.string(from: latest))"
    }

    private var cassettePhotoDateRange: String {
        guard let c = mainCassette, let range = c.photoDateRange else { return "--" }
        return "\(fmt.string(from: range.oldest)) - \(fmt.string(from: range.latest))"
    }

    private var isKorean: Bool {
        Locale.current.language.languageCode?.identifier == "ko"
    }

    private var tosURL: URL {
        let urlString = isKorean
            ? "https://polydactyl-alder-784.notion.site/3821d0eacd8f80d3aad9c76950ef7f18"
            : "https://polydactyl-alder-784.notion.site/Terms-of-Services-3821d0eacd8f80e9b4f2f72aabee40b1"
        return URL(string: urlString)!
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            switch mode {
            case .overall:
                if cassettes.isEmpty {
                    Text("no cassettes yet!")
                        .font(.cutiveMono(24))
                        .foregroundColor(.appBlack)
                        .frame(height: 30)
                    Text("add a new cassette")
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .frame(height: 23)
                    Text("with your b-cuts")
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .frame(height: 23)
                } else {
                    Text("\(cassettes.count) cassettes")
                        .font(.cutiveMono(24))
                        .foregroundColor(.appBlack)
                        .frame(height: 30)
                    Text(overallDateRange)
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .frame(height: 23)
                    Text("\(totalPhotos) photos")
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .frame(height: 23)
                }
                Link("terms of service", destination: tosURL)
                    .font(.custom("SF Mono", size: 13).monospaced())
                    .kerning(13 * 0.08)
                    .foregroundColor(.appDarkGray)
                    .underline()
                    .frame(height: 23)

            case .cassette:
                if let c = mainCassette {
                    Text(c.name)
                        .font(.cutiveMono(24))
                        .foregroundColor(.appBlack)
                        .frame(height: 30)
                    Text(cassettePhotoDateRange)
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .frame(height: 23)
                    Text("\(c.photos.count) photos")
                        .font(.cutiveMono(16))
                        .foregroundColor(.appBlack)
                        .frame(height: 23)
                    Text(c.isExpired ? "expired" : "\(c.daysLeft) days left")
                        .font(.custom("SF Mono", size: 13).monospaced())
                        .kerning(13 * 0.08)
                        .frame(height: 23)
                        .foregroundColor(c.isExpired ? .appGray : .appAccent)
                }
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .frame(width: 345, height: 140, alignment: .topTrailing)
        .background(Color.appWhite)
        .overlay(Rectangle().stroke(Color.appBlack, lineWidth: 1))
        .padding(.bottom, 40)
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.25), value: visible)
        .animation(.easeInOut(duration: 0.25), value: mode == .overall)
        .zIndex(100)
        .allowsHitTesting(visible)
    }
}

#Preview {
    MainScreen()
        .environmentObject(AppState())
}
