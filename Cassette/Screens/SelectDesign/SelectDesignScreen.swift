import SwiftUI
import Photos

// MARK: - DesignTab

enum DesignTab {
    case cassette, text, sticker
}

// MARK: - Cassette Color

struct CassetteColor: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
    var imageName: String { "cassette_\(name)" }
}

let cassetteColors: [CassetteColor] = [
    CassetteColor(name: "black",   hex: "000000"),
    CassetteColor(name: "white",   hex: "FFFFFF"),
    CassetteColor(name: "pink",    hex: "FFB3CD"),
    CassetteColor(name: "purple",  hex: "D0A4FF"),
    CassetteColor(name: "blue",    hex: "6FB0FF"),
    CassetteColor(name: "skyblue", hex: "7AE8FF"),
    CassetteColor(name: "mint",    hex: "87F1C1"),
    CassetteColor(name: "green",   hex: "C0F69E"),
    CassetteColor(name: "yellow",  hex: "F7F288"),
    CassetteColor(name: "orange",  hex: "FFB389"),
    CassetteColor(name: "red",     hex: "FF9696"),
]

// MARK: - SelectDesignScreen

struct SelectDesignScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert = false
    @State private var isSaving = false
    @State private var showToast = false
    @State private var showTypePopup = false
    @State private var selectedTab: DesignTab = .cassette

    private let canvasWidth: CGFloat = 345

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
                    Text("make a cassette")
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
                .padding(.bottom, 12)

                // ── 카세트 이름 ──
                VStack(spacing: 6) {
                    Text(cassetteData.name.isEmpty ? "untitled" : cassetteData.name)
                        .font(.appTitle)
                        .foregroundColor(.appBlack)
                        .frame(width: 257, height: 26)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                        .background(Color.appWhite)
                        .frame(width: 289, height: 36)
                    Text(dateRangeString)
                        .font(.appBody)
                        .foregroundColor(.appDarkGray)
                }
                .padding(.bottom, 16)

                // ── 카세트 프리뷰 ──
                CassetteCanvasView(
                    colorName: cassetteData.selectedCassetteColor,
                    width: canvasWidth
                )
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)

                // ── 하단 편집 패널 ──
                VStack(spacing: 0) {

                    // 탭 버튼
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            tabButton(.cassette, icon: "button_cassette", width: geo.size.width / 3)
                            tabButton(.text,     icon: "button_text",     width: geo.size.width / 3)
                            tabButton(.sticker,  icon: "button_sticker",  width: geo.size.width / 3)
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 60)

                    // 탭 콘텐츠
                    Group {
                        switch selectedTab {
                        case .cassette:
                            CassetteSelectPanel(selectedColor: $cassetteData.selectedCassetteColor)
                        case .text:
                            TextEditPanel()
                        case .sticker:
                            StickerEditPanel()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .background(
                    Color.appLightGray
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 12,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 12
                            )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 0)
                        .ignoresSafeArea(edges: .bottom)
                )
                .frame(height: UIScreen.main.bounds.height * 0.45)
            }

            // ── 토스트 ──
            if showToast {
                Text("photos must be deleted\nto create a cassette")
                    .font(.appMicro)
                    .foregroundColor(.appWhite)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.appDarkGray))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .transition(.opacity)
                    .zIndex(999)
            }

            // ── Done 버튼 ──
            VStack(spacing: 0) {
                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    Task {
                        await renderOnly()
                        isSaving = false
                        withAnimation(.easeOut(duration: 0.25)) { showTypePopup = true }
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .appWhite))
                        } else {
                            Text("done")
                                .font(.appBody)
                                .foregroundColor(.appWhite)
                        }
                    }
                    .frame(width: 201, height: 48)
                    .background(Capsule().fill(Color.appDarkGray))
                }
                Spacer().frame(height: 11)
            }
            .frame(maxWidth: .infinity)

            // ── Type 선택 팝업 ──
            if showTypePopup {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.2)) { showTypePopup = false }
                    }
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                SelectTypePopup(
                    onDismiss: {
                        withAnimation(.easeIn(duration: 0.2)) { showTypePopup = false }
                    },
                    onSelect: { isSpecial in
                        cassetteData.isSpecial = isSpecial
                        showTypePopup = false
                        Task { await finishAndSave() }
                    }
                )
                .environmentObject(appState)
                .environmentObject(cassetteData)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .navigationBarHidden(true)
        .alert("Leave without saving?", isPresented: $showExitAlert) {
            Button("leave", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("Your cassette won't be saved.")
        }
    }

    // MARK: - 탭 버튼

    @ViewBuilder
    private func tabButton(_ tab: DesignTab, icon: String, width: CGFloat) -> some View {
        Button { selectedTab = tab } label: {
            ZStack {
                if selectedTab == tab {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.appBackground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                Image(icon)
                    .resizable().scaledToFit()
                    .frame(width: 40, height: 40)
            }
            .frame(width: width, height: 60)
        }
    }

    // MARK: - 렌더링

    @MainActor
    private func renderOnly() async {
        let renderWidth: CGFloat = 1035
        let renderView = CassetteCanvasView(
            colorName: cassetteData.selectedCassetteColor,
            width: renderWidth,
            applyMask: true
        )
        let renderer = ImageRenderer(content: renderView)
        renderer.scale = 1.0

        if let uiImage = renderer.uiImage,
           let pngData = uiImage.pngData() {
            let relativePath = "cassettes/\(cassetteData.cassetteID.uuidString)/design.png"
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("cassettes/\(cassetteData.cassetteID.uuidString)")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let absURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(relativePath)
            try? pngData.write(to: absURL)
            cassetteData.customImagePath = relativePath
        }
    }

    // MARK: - 사진 삭제 + 저장

    @MainActor
    private func finishAndSave() async {
        let ids = cassetteData.assetIDsToDelete
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }

        appState.deleteFromPhotos(assets: assets) { success in
            if !success {
                print("[DEBUG] photo deletion denied or failed — skipping for internal testing")
            }
            let newCassette = cassetteData.buildCassette()
            appState.addCassette(newCassette)
            cassetteData.shouldDismiss = true
        }
    }
}

// MARK: - CassetteCanvasView

struct CassetteCanvasView: View {
    let colorName: String
    let width: CGFloat
    var applyMask: Bool = false

    var body: some View {
        ZStack {
            // 0. 테이프 (최하단)
            Image("tape")
                .resizable()
                .scaledToFit()
            // 1. 카세트 색상
            Image("cassette_\(colorName)")
                .resizable()
                .scaledToFit()
            // 2. 볼트/하드웨어
            Image("bolts")
                .resizable()
                .scaledToFit()
            // 3. 사용자 커스터마이징 레이어 (text, sticker 등 여기에 추가)
        }
        .frame(width: width)
        .modifier(CassetteMaskModifier(width: width, apply: applyMask))
    }
}

struct CassetteMaskModifier: ViewModifier {
    let width: CGFloat
    let apply: Bool

    func body(content: Content) -> some View {
        if apply {
            content.mask(
                Image("cassette_mask")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
            )
        } else {
            content
        }
    }
}

// MARK: - CassetteSelectPanel

struct CassetteSelectPanel: View {
    @Binding var selectedColor: String

    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // ── 카세트 타입 선택 ──
                HStack(spacing: 12) {
                    // 현재 유일한 디자인
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.appBlack, lineWidth: 1.5)
                            )
                        Image("cassette_\(selectedColor)")
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                    }
                    .frame(width: 110, height: 74)

                    // coming soon 슬롯
                    ForEach(0..<2) { _ in
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.appWhite)
                            Text("coming\nsoon")
                                .font(.appMicro)
                                .foregroundColor(.appGray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 110, height: 74)
                    }
                }
                .padding(.horizontal, 24)

                // ── 컬러 팔레트 ──
                LazyVGrid(columns: colorColumns, spacing: 8) {
                    ForEach(cassetteColors) { c in
                        let isSelected = selectedColor == c.name
                        Button {
                            selectedColor = c.name
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(c.color)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.appGray.opacity(0.3), lineWidth: c.name == "white" ? 1 : 0)
                                    )
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color.appBlack, lineWidth: 2)
                                        .aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 60)
            }
            .padding(.top, 16)
        }
    }
}

// MARK: - Text 탭

struct TextEditPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("coming soon")
                .font(.appMicro)
                .foregroundColor(.appGray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 24)
            Spacer()
        }
    }
}

// MARK: - Sticker 탭

struct StickerEditPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("coming soon")
                .font(.appMicro)
                .foregroundColor(.appGray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 24)
            Spacer()
        }
    }
}
