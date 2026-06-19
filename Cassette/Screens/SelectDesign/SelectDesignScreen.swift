import SwiftUI
import Photos

// MARK: - DesignTab

enum DesignTab {
    case type, color, text, sticker
}

// 1 = 통자형(all same), 2 = 2색, 3 = 3색
enum CassetteColorType: Int, CaseIterable {
    case solid = 1, dual = 2, triple = 3
}

// MARK: - SelectDesignScreen

struct SelectDesignScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var cassetteData: NewCassetteData
    @Environment(\.dismiss) var dismiss

    @State private var showExitAlert = false
    @State private var isSaving = false
    @State private var showToast = false
    @State private var showTypePopup = false
    @State private var selectedTab: DesignTab = .type
    @State private var colorType: CassetteColorType = .solid

    private let canvasWidth: CGFloat = 345

    private let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd"; return f
    }()

    // type에 따라 각 레이어에 실제로 적용할 색 결정
    var effectiveLayer1: LayerColor { cassetteData.layer1Color }
    var effectiveLayer2: LayerColor {
        switch colorType {
        case .solid: return cassetteData.layer1Color
        case .dual:  return cassetteData.layer2Color
        case .triple: return cassetteData.layer2Color
        }
    }
    var effectiveLayer3: LayerColor {
        switch colorType {
        case .solid: return cassetteData.layer1Color
        case .dual:  return cassetteData.layer2Color
        case .triple: return cassetteData.layer3Color
        }
    }

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
                    layer1: effectiveLayer1,
                    layer2: effectiveLayer2,
                    layer3: effectiveLayer3,
                    width: canvasWidth
                )
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)

                // ── 하단 편집 패널 ──
                VStack(spacing: 0) {

                    // 탭 버튼
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            tabButton(.type,    icon: "button_cassette", width: geo.size.width / 4)
                            tabButton(.color,   icon: "button_palette",  width: geo.size.width / 4)
                            tabButton(.text,    icon: "button_text",     width: geo.size.width / 4)
                            tabButton(.sticker, icon: "button_sticker",  width: geo.size.width / 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 60)

                    // 탭 콘텐츠
                    Group {
                        switch selectedTab {
                        case .type:
                            TypeSelectPanel(colorType: $colorType)
                        case .color:
                            ColorEditPanel(
                                layer1: $cassetteData.layer1Color,
                                layer2: $cassetteData.layer2Color,
                                layer3: $cassetteData.layer3Color,
                                colorType: colorType
                            )
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
        .onChange(of: colorType) {
            switch colorType {
            case .solid:
                cassetteData.layer2Color.brightness = 0
                cassetteData.layer3Color.brightness = 0
            case .dual:
                cassetteData.layer2Color.brightness = 0.35
                cassetteData.layer3Color.brightness = 0
            case .triple:
                cassetteData.layer2Color.brightness = 0.35
                cassetteData.layer3Color.brightness = 1.0
            }
        }
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

    // MARK: - 렌더링만 (done 버튼 시)

    @MainActor
    private func renderOnly() async {
        let renderWidth: CGFloat = 1035
        let renderView = CassetteCanvasView(
            layer1: effectiveLayer1,
            layer2: effectiveLayer2,
            layer3: effectiveLayer3,
            width: renderWidth
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

    // MARK: - 사진 삭제 + 저장 (type 선택 후)

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
    let layer1: LayerColor
    let layer2: LayerColor
    let layer3: LayerColor
    let width: CGFloat

    var body: some View {
        ZStack {
            Image("cassette_layer0").resizable().scaledToFit()
            colorizedLayer(imageName: "cassette_layer3", layer: layer3)
            colorizedLayer(imageName: "cassette_layer2", layer: layer2)
            colorizedLayer(imageName: "cassette_layer1", layer: layer1)
        }
        .frame(width: width)
        .mask(
            Image("cassette_mask")
                .resizable()
                .scaledToFit()
                .frame(width: width)
        )
    }

    @ViewBuilder
    private func colorizedLayer(imageName: String, layer: LayerColor) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .colorMultiply(Color(hue: layer.hue, saturation: layer.saturation, brightness: 1.0))
            .saturation(1.0 + layer.saturation * 4.0)
            .brightness(layer.brightness * 0.2)
    }
}

// MARK: - Type 탭

struct TypeSelectPanel: View {
    @Binding var colorType: CassetteColorType

    private let types: [(type: CassetteColorType, imageName: String)] = [
        (.solid,  "type_1color"),
        (.dual,   "type_2color"),
        (.triple, "type_3color"),
    ]

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(types, id: \.type) { item in
                    Button { colorType = item.type } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(colorType == item.type ? Color.appBackground : Color.appWhite)
                            Image(item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 128)
                        }
                        .frame(width: 165, height: 110)
                    }
                }
                // more coming soon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appWhite)
                    Text("more\ncoming soon")
                        .font(.appMicro)
                        .foregroundColor(.appGray)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 165, height: 110)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            Spacer().frame(height: 60)
        }
    }
}

// MARK: - Color 탭

struct ColorEditPanel: View {
    @Binding var layer1: LayerColor
    @Binding var layer2: LayerColor
    @Binding var layer3: LayerColor
    let colorType: CassetteColorType

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // back layer: 항상 활성
                LayerColorSection(title: "back layer", layerColor: $layer1)

                // inner layer: dual, triple만 활성
                LayerColorSection(
                    title: "inner layer",
                    layerColor: $layer2,
                    disabled: colorType == .solid
                )

                // center layer: triple만 활성
                LayerColorSection(
                    title: "center layer",
                    layerColor: $layer3,
                    disabled: colorType != .triple
                )

                Spacer().frame(height: 60)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }
}

struct LayerColorSection: View {
    let title: String
    @Binding var layerColor: LayerColor
    var disabled: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.appBody)
                .foregroundColor(disabled ? .appGray : .appBlack)
                .frame(maxWidth: .infinity, alignment: .center)

            // Hue
            HSBSlider(
                value: $layerColor.hue,
                track: LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 0.05).map {
                        Color(hue: $0, saturation: 1, brightness: 1)
                    },
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                disabled: disabled
            )

            // Saturation
            HSBSlider(
                value: $layerColor.saturation,
                track: LinearGradient(
                    colors: [
                        Color(hue: layerColor.hue, saturation: 0, brightness: 1),
                        Color(hue: layerColor.hue, saturation: 1, brightness: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                disabled: disabled
            )

            // Brightness
            HSBSlider(
                value: $layerColor.brightness,
                track: LinearGradient(
                    colors: [.black, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                disabled: disabled
            )
        }
        .opacity(disabled ? 0.35 : 1.0)
        .allowsHitTesting(!disabled)
    }
}

struct HSBSlider: View {
    @Binding var value: Double
    let track: LinearGradient
    var disabled: Bool = false

    var body: some View {
        GeometryReader { geo in
            let thumbSize: CGFloat = 20
            let trackWidth = geo.size.width - thumbSize

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                    .frame(height: 6)
                    .padding(.horizontal, thumbSize / 2)

                Circle()
                    .fill(Color.appWhite)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .offset(x: CGFloat(value) * trackWidth)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let raw = drag.location.x / trackWidth
                                value = max(0, min(1, raw))
                            }
                    )
            }
        }
        .frame(height: 20)
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
