import SwiftUI
import Photos

// MARK: - Text Layer

struct CassetteTextLayer: Identifiable {
    let id = UUID()
    var text: String
    var font: CassetteFont
    var size: TextSize
    var colorHex: String
    var offset: CGSize
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Text Edit Enums

enum TextEditTab { case font, size, color }

enum CassetteFont: String, CaseIterable {
    case inspiration = "Inspiration"
    case cutiveMono  = "Cutive Mono"
    case pretendard  = "Pretendard"

    var displayName: String { rawValue }

    func swiftUIFont(size: CGFloat) -> Font {
        switch self {
        case .inspiration: return .custom("Inspiration", size: size)
        case .cutiveMono:  return .custom("CutiveMono-Regular", size: size)
        case .pretendard:  return .custom("Pretendard-Regular", size: size)
        }
    }
}

enum TextSize: String, CaseIterable {
    case small = "S", medium = "M", large = "L", extraLarge = "XL"
    var pointSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 20
        case .large: return 28
        case .extraLarge: return 36
        }
    }
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
    @State private var showCassettePanel = false
    @State private var showStickerPanel = false
    @State private var stickerTab: StickerTab = .image
    @State private var stickerStyle: StickerStyle = .background
    @State private var selectedStickerPhoto: BCutPhoto? = nil
    @State private var previewImageLayer: CassetteImageLayer? = nil
    @State private var confirmedImageItems: [CassetteImageLayer] = []

    // ── Text 편집 ──
    @State private var showTextEditor = false
    @State private var textInput = ""
    @State private var selectedTextTab: TextEditTab = .font
    @State private var selectedFont: CassetteFont = .inspiration
    @State private var selectedTextSize: TextSize = .medium
    @State private var selectedTextColorHex: String = "FFFFFF"
    @State private var keyboardHeight: CGFloat = 0
    @State private var textDragOffset: CGSize = .zero
    @State private var textDragBase: CGSize = .zero
    @State private var textScale: CGFloat = 1.0
    @State private var textScaleBase: CGFloat = 1.0
    @State private var textRotation: Angle = .zero
    @State private var textRotationBase: Angle = .zero
    @State private var confirmedTextItems: [CassetteTextLayer] = []
    @State private var editingLayerID: UUID? = nil
    @State private var cassetteFrame: CGRect = .zero
    @State private var editingTextSquare: CGFloat = 80
    @FocusState private var textFieldFocused: Bool

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
                    Button {
                        if showTextEditor {
                            showTextEditor = false
                            textFieldFocused = false
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(showTextEditor ? "button_chevronLeft" : "button_chevronLeft")
                            .resizable().scaledToFit()
                            .frame(width: 24, height: 24)
                    }
                    Spacer()
                    Text("make a cassette")
                        .font(.appTitle)
                        .foregroundColor(.appBlack)
                    Spacer()
                    if showTextEditor {
                        Button {
                            if !textInput.isEmpty {
                                confirmedTextItems.append(CassetteTextLayer(
                                    text: textInput,
                                    font: selectedFont,
                                    size: selectedTextSize,
                                    colorHex: selectedTextColorHex,
                                    offset: textDragOffset,
                                    scale: textScale,
                                    rotation: textRotation
                                ))
                            }
                            textInput = ""
                            textDragOffset = .zero
                            textDragBase = .zero
                            textScale = 1.0
                            textScaleBase = 1.0
                            textRotation = .zero
                            textRotationBase = .zero
                            editingLayerID = nil
                            showTextEditor = false
                            textFieldFocused = false
                        } label: {
                            Text("done")
                                .font(.appBody)
                                .foregroundColor(.appWhite)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.appDarkGray))
                        }
                    } else {
                        Button { showExitAlert = true } label: {
                            Image("button_x")
                                .resizable().scaledToFit()
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)

                // ── 숨겨진 TextField (키보드용) ──
                if showTextEditor {
                    TextField("", text: $textInput)
                        .focused($textFieldFocused)
                        .opacity(0)
                        .frame(height: 0)
                }

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
                    width: canvasWidth,
                    textLayers: [],
                    imageLayers: []
                )
                .frame(width: canvasWidth)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            cassetteFrame = geo.frame(in: .named("outerZStack"))
                        }.onChange(of: geo.frame(in: .named("outerZStack"))) {
                            cassetteFrame = geo.frame(in: .named("outerZStack"))
                        }
                    }
                )

                // ── 스티커 style 버튼 (스티커 패널 열릴때만 표시) ──
                if showStickerPanel {
                    HStack(spacing: 12) {
                        styleButton(icon: "button_background", style: .background)
                        styleButton(icon: "button_foreground", style: .foreground)
                    }
                    .padding(.top, 16)
                    .transition(.opacity)
                }

                Spacer()

                // ── 하단 3개 버튼 ──
                if showTextEditor { Spacer().frame(height: 16) }
                HStack(spacing: 24) {
                    Spacer()
                    if !showTextEditor {
                        toolButton(icon: "button_cassette") {
                            withAnimation(.easeInOut(duration: 0.25)) { showCassettePanel.toggle() }
                        }
                        toolButton(icon: "button_text") {
                            showTextEditor = true
                            textFieldFocused = true
                        }
                        toolButton(icon: "button_sticker") {
                            withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel.toggle() }
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 16)

                // ── Done 버튼 (텍스트 모드일때 숨김) ──
                if showTextEditor { Spacer().frame(height: 59) }
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
                .padding(.bottom, 11)
                .opacity(showTextEditor ? 0 : 1)
            }

            // ── 패널 열려있을 때 뒤쪽 탭으로 닫기 ──
            if showCassettePanel || showStickerPanel {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCassettePanel = false
                            showStickerPanel = false
                        }
                        previewImageLayer = nil
                        selectedStickerPhoto = nil
                    }
                    .zIndex(9)
            }

            // ── 카세트 패널 (인라인, 어두운 오버레이 없음) ──
            if showCassettePanel {
                CassetteSelectPanel(
                    selectedColor: $cassetteData.selectedCassetteColor,
                    onDone: {
                        withAnimation(.easeInOut(duration: 0.25)) { showCassettePanel = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(10)
            }

            // ── 텍스트 편집 모드 어두운 오버레이 (확정 레이어들 위, 편집 텍스트 아래) ──
            if showTextEditor && keyboardHeight > 0 {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(17)
                    .allowsHitTesting(false)
            }

            // ── 이미지 레이어들 (드래그/핀치/회전 가능) ──
            ForEach($confirmedImageItems) { $item in
                ConfirmedImageLayerView(item: $item, cassetteFrame: cassetteFrame)
                    .allowsHitTesting(!showTypePopup)
                    .zIndex(15)
            }

            // ── 스티커 프리뷰 레이어 (선택 즉시 표시, done 전) ──
            if let _ = previewImageLayer {
                ConfirmedImageLayerView(item: Binding(
                    get: { previewImageLayer! },
                    set: { previewImageLayer = $0 }
                ), cassetteFrame: cassetteFrame)
                .id(previewImageLayer?.id)
                .allowsHitTesting(!showTypePopup)
                .zIndex(15)
            }

            // ── 완성된 텍스트 레이어들 (드래그/핀치/회전/탭 편집 가능) ──
            ForEach($confirmedTextItems) { $item in
                ConfirmedTextLayerView(
                    item: $item,
                    cassetteFrame: cassetteFrame
                ) {
                    // 탭 → 편집 모드 진입
                    editingLayerID = item.id
                    textInput = item.text
                    selectedFont = item.font
                    selectedTextSize = item.size
                    selectedTextColorHex = item.colorHex
                    textDragOffset = item.offset
                    textDragBase = item.offset
                    textScale = item.scale
                    textScaleBase = item.scale
                    textRotation = item.rotation
                    textRotationBase = item.rotation
                    confirmedTextItems.removeAll { $0.id == item.id }
                    showTextEditor = true
                    textFieldFocused = true
                }
                .allowsHitTesting(!showTypePopup)
                .zIndex(16)
            }

            // ── 편집 중 텍스트 레이어 (어두운 오버레이 위, zIndex 18) ──
            if showTextEditor && !textInput.isEmpty {
                Text(textInput)
                    .font(selectedFont.swiftUIFont(size: selectedTextSize.pointSize))
                    .foregroundColor(Color(hex: selectedTextColorHex))
                    .padding(8)
                    .fixedSize()
                    .background(GeometryReader { geo in
                        Color.clear.onAppear { editingTextSquare = max(geo.size.width, geo.size.height) }
                            .onChange(of: geo.size) { editingTextSquare = max(geo.size.width, geo.size.height) }
                    })
                    .frame(minWidth: editingTextSquare, minHeight: editingTextSquare)
                    .contentShape(Rectangle())
                    .scaleEffect(textScale)
                    .rotationEffect(textRotation)
                    .position(
                        x: cassetteFrame.midX + textDragOffset.width,
                        y: cassetteFrame.midY + textDragOffset.height
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                textDragOffset = CGSize(
                                    width: textDragBase.width + v.translation.width,
                                    height: textDragBase.height + v.translation.height
                                )
                            }
                            .onEnded { _ in textDragBase = textDragOffset }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { v in textScale = textScaleBase * v }
                            .onEnded { _ in textScaleBase = textScale }
                    )
                    .simultaneousGesture(
                        RotationGesture()
                            .onChanged { v in textRotation = textRotationBase + v }
                            .onEnded { _ in textRotationBase = textRotation }
                    )
                    .zIndex(18)
            }

            // ── 텍스트 편집 툴바 (키보드 바로 위) ──
            if showTextEditor && keyboardHeight > 0 {
                TextEditorToolbar(
                    selectedTab: $selectedTextTab,
                    selectedFont: $selectedFont,
                    selectedSize: $selectedTextSize,
                    selectedColorHex: $selectedTextColorHex
                )
                .frame(maxWidth: .infinity)
                .offset(y: -keyboardHeight)
                .zIndex(20)
            }

            // ── 스티커 패널 (인라인, 어두운 오버레이 없음) ──
            if showStickerPanel {
                StickerEditPanel(
                    selectedTab: $stickerTab,
                    selectedStyle: $stickerStyle,
                    selectedPhoto: $selectedStickerPhoto,
                    photos: cassetteData.selectedPhotos,
                    onSelect: { photo in
                        if let photo {
                            previewImageLayer = CassetteImageLayer(photo: photo)
                        } else {
                            previewImageLayer = nil
                        }
                    },
                    onDone: {
                        if let layer = previewImageLayer {
                            confirmedImageItems.append(layer)
                        }
                        previewImageLayer = nil
                        selectedStickerPhoto = nil
                        withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(10)
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

            // ── Type 선택 팝업 ──
            if showTypePopup {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeIn(duration: 0.2)) { showTypePopup = false }
                    }
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(50)

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
                .zIndex(51)
            }
        }
        .coordinateSpace(name: "outerZStack")
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            if let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .alert("Leave without saving?", isPresented: $showExitAlert) {
            Button("leave", role: .destructive) { cassetteData.shouldDismiss = true }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("Your cassette won't be saved.")
        }
    }

    // MARK: - 툴 버튼

    @ViewBuilder
    private func toolButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.appWhite)
                    .frame(width: 56, height: 56)
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            }
        }
    }

    @ViewBuilder
    private func styleButton(icon: String, style: StickerStyle) -> some View {
        Button {
            stickerStyle = style
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(stickerStyle == style ? Color.appBlack : Color.appWhite)
                    .frame(width: 48, height: 48)
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .colorMultiply(stickerStyle == style ? .white : .black)
            }
        }
    }

    // MARK: - 렌더링

    @MainActor
    private func renderOnly() async {
        let renderWidth: CGFloat = 1035
        let renderView = CassetteCanvasView(
            colorName: cassetteData.selectedCassetteColor,
            width: renderWidth,
            applyMask: true,
            textLayers: confirmedTextItems,
            imageLayers: confirmedImageItems
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
    var textLayers: [CassetteTextLayer] = []
    var imageLayers: [CassetteImageLayer] = []

    // 345가 기준 canvasWidth — 렌더 시 scale 보정에 사용
    private let baseWidth: CGFloat = 345

    var body: some View {
        ZStack {
            Image("tape").resizable().scaledToFit()
            Image("cassette_\(colorName)").resizable().scaledToFit()
            Image("bolts").resizable().scaledToFit()

            // ── 이미지 레이어 ──
            let s = width / baseWidth
            ForEach(imageLayers) { item in
                if let img = item.loadedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120 * s, height: 120 * s)
                        .scaleEffect(item.scale)
                        .rotationEffect(item.rotation)
                        .offset(x: item.offset.width * s, y: item.offset.height * s)
                }
            }

            // ── 텍스트 레이어 ──
            ForEach(textLayers) { item in
                Text(item.text)
                    .font(item.font.swiftUIFont(size: item.size.pointSize * s))
                    .foregroundColor(item.color)
                    .scaleEffect(item.scale)
                    .rotationEffect(item.rotation)
                    .offset(x: item.offset.width * s, y: item.offset.height * s)
            }
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

// MARK: - CassetteSelectPanel (인라인)

struct CassetteSelectPanel: View {
    @Binding var selectedColor: String
    var onDone: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // drag indicator
            Capsule()
                .fill(Color.appGray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // ── 타이틀 ──
            Text("cassette type")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .padding(.bottom, 16)

            // ── 카세트 타입 선택 (가로 스크롤) ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.appBlack, lineWidth: 1.5)
                            )
                        Image("cassette_\(selectedColor)")
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                    .frame(width: 98, height: 66)

                    ForEach(0..<3, id: \.self) { _ in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appWhite)
                            Text("coming\nsoon")
                                .font(.appMicro)
                                .foregroundColor(.appGray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 98, height: 66)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)

            // ── 컬러 팔레트 ──
            let rows = stride(from: 0, to: cassetteColors.count, by: 6).map {
                Array(cassetteColors[$0..<min($0 + 6, cassetteColors.count)])
            }
            VStack(spacing: 6) {
                ForEach(rows, id: \.first?.id) { row in
                    HStack(spacing: 6) {
                        ForEach(row) { c in
                            let isSelected = selectedColor == c.name
                            Button { selectedColor = c.name } label: {
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
                        if row.count < 6 {
                            ForEach(0..<(6 - row.count), id: \.self) { _ in
                                Color.clear.aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // ── done ──
            Button {
                onDone?()
            } label: {
                Text("done")
                    .font(.appBody)
                    .foregroundColor(.appWhite)
                    .frame(width: 201, height: 48)
                    .background(Capsule().fill(Color.appDarkGray))
            }
            .padding(.bottom, 11)
        }
        .frame(height: 387)
        .clipped()
        .background(
            Color(hex: "F7F7F7")
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                ))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Sticker Enums

enum StickerTab { case image, emoji }
enum StickerStyle { case background, foreground }

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
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Sticker 패널

struct StickerEditPanel: View {
    @Binding var selectedTab: StickerTab
    @Binding var selectedStyle: StickerStyle
    @Binding var selectedPhoto: BCutPhoto?
    let photos: [BCutPhoto]
    var onSelect: (BCutPhoto?) -> Void = { _ in }
    var onDone: () -> Void

    private let photoColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            // drag indicator
            Capsule()
                .fill(Color.appGray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // ── 탭 버튼 ──
            HStack(spacing: 12) {
                tabButton(icon: "button_image", tab: .image)
                tabButton(icon: "button_emoji", tab: .emoji)
            }
            .padding(.bottom, 12)

            Divider()

            // ── 탭 콘텐츠 ──
            ScrollView(showsIndicators: false) {
                switch selectedTab {
                case .image:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("b-cut from film")
                            .font(.appMicro)
                            .foregroundColor(.appDarkGray)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        LazyVGrid(columns: photoColumns, spacing: 2) {
                            ForEach(photos) { photo in
                                let isSelected = selectedPhoto?.id == photo.id
                                StickerPhotoCell(photo: photo, isSelected: isSelected)
                                    .onTapGesture {
                                        let next: BCutPhoto? = isSelected ? nil : photo
                                        selectedPhoto = next
                                        onSelect(next)
                                    }
                            }
                        }
                    }
                case .emoji:
                    Text("coming soon")
                        .font(.appMicro)
                        .foregroundColor(.appGray)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }
            }

            // ── done 버튼 ──
            Button { onDone() } label: {
                Text("done")
                    .font(.appBody)
                    .foregroundColor(.appWhite)
                    .frame(width: 201, height: 48)
                    .background(Capsule().fill(selectedPhoto != nil ? Color.appDarkGray : Color(hex: "B3B3B3")))
            }
            .disabled(selectedPhoto == nil)
            .padding(.vertical, 11)
        }
        .frame(height: 387)
        .clipped()
        .background(
            Color(hex: "F7F7F7")
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                ))
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func tabButton(icon: String, tab: StickerTab) -> some View {
        let isSelected = selectedTab == tab
        Button { selectedTab = tab } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : Color(hex: "B3B3B3"))
                    .frame(width: 72, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.black : Color.clear, lineWidth: 1)
                    )
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
        }
    }
}

struct StickerPhotoCell: View {
    let photo: BCutPhoto
    var isSelected: Bool = false
    @State private var image: UIImage? = nil

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.appGray.opacity(0.2)
                    }
                }
            )
            .clipped()
            .contentShape(Rectangle())
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
            .overlay(isSelected ? Color.black.opacity(0.15) : Color.clear)
            .onAppear { loadImage() }
    }

    func loadImage() {
        if case .file(let url) = photo.imageSource,
           let img = UIImage(contentsOfFile: url.path) {
            image = img
            return
        }
        if case .asset(let id) = photo.imageSource {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = result.firstObject else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: opts) { img, _ in
                if let img { DispatchQueue.main.async { image = img } }
            }
        }
    }
}

// MARK: - TextEditorToolbar

struct TextEditorToolbar: View {
    @Binding var selectedTab: TextEditTab
    @Binding var selectedFont: CassetteFont
    @Binding var selectedSize: TextSize
    @Binding var selectedColorHex: String

    private let textColorHexes: [String] = [
        "FFFFFF", "000000",
        "FF0000", "FF7C00", "FFC500",
        "00C50D", "009CFF", "C300C8",
        "333333", "555555", "777777", "999999"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── 탭 버튼 row ──
            HStack(spacing: 0) {
                tabButton("font", tab: .font)
                tabButton("size", tab: .size)
                tabButton("color", tab: .color)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            Divider()

            // ── 탭 콘텐츠 ──
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    switch selectedTab {
                    case .font:
                        ForEach(CassetteFont.allCases, id: \.self) { f in
                            fontChip(f)
                        }
                    case .size:
                        ForEach(TextSize.allCases, id: \.self) { s in
                            sizeChip(s)
                        }
                    case .color:
                        ForEach(Array(textColorHexes.enumerated()), id: \.offset) { i, hex in
                            colorChip(hex, index: i)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .background(Color(hex: "F7F7F7"))
    }

    @ViewBuilder
    private func tabButton(_ label: String, tab: TextEditTab) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.appBody)
                    .foregroundColor(selectedTab == tab ? .appBlack : .appGray)
                Rectangle()
                    .fill(selectedTab == tab ? Color.appBlack : Color.clear)
                    .frame(height: 1.5)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func fontChip(_ f: CassetteFont) -> some View {
        let isSelected = selectedFont == f
        Button { selectedFont = f } label: {
            Text(f.displayName)
                .font(f.swiftUIFont(size: 14))
                .foregroundColor(isSelected ? .appWhite : .appBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.appBlack : Color.appWhite)
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.clear : Color.appGray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func sizeChip(_ s: TextSize) -> some View {
        let isSelected = selectedSize == s
        Button { selectedSize = s } label: {
            Text(s.rawValue)
                .font(.appBody)
                .foregroundColor(isSelected ? .appWhite : .appBlack)
                .frame(width: 44, height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.appBlack : Color.appWhite))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Color.clear : Color.appGray.opacity(0.3), lineWidth: 1))
        }
    }

    @ViewBuilder
    private func colorChip(_ hex: String, index: Int) -> some View {
        let isSelected = selectedColorHex.uppercased() == hex.uppercased()
        let isWhite = index == 0
        Button { selectedColorHex = hex } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Color(hex: "CCCCCC"), lineWidth: isWhite ? 1 : 0))
                .overlay(Circle().strokeBorder(Color(hex: "000000"), lineWidth: isSelected ? 2.5 : 0).padding(-2))
        }
    }
}

// MARK: - CassetteImageLayer

struct CassetteImageLayer: Identifiable {
    let id = UUID()
    var photo: BCutPhoto
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var loadedImage: UIImage? = nil
}

// MARK: - ConfirmedImageLayerView

struct ConfirmedImageLayerView: View {
    @Binding var item: CassetteImageLayer
    let cassetteFrame: CGRect

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var magnifyDelta: CGFloat = 1.0
    @GestureState private var rotateDelta: Angle = .zero
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipped()
            } else {
                Color.appGray.opacity(0.3)
                    .frame(width: 120, height: 120)
            }
        }
        .scaleEffect(item.scale * magnifyDelta)
        .rotationEffect(item.rotation + rotateDelta)
        .position(
            x: cassetteFrame.midX + item.offset.width + dragDelta.width,
            y: cassetteFrame.midY + item.offset.height + dragDelta.height
        )
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragDelta) { v, state, _ in state = v.translation }
                .onEnded { v in
                    item.offset.width += v.translation.width
                    item.offset.height += v.translation.height
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .updating($magnifyDelta) { v, state, _ in state = v }
                .onEnded { v in item.scale = max(0.1, item.scale * v) }
        )
        .simultaneousGesture(
            RotationGesture()
                .updating($rotateDelta) { v, state, _ in state = v }
                .onEnded { v in item.rotation += v }
        )
        .onAppear { loadImage() }
    }

    func loadImage() {
        if case .file(let url) = item.photo.imageSource,
           let img = UIImage(contentsOfFile: url.path) {
            image = img
            item.loadedImage = img
            return
        }
        if case .asset(let id) = item.photo.imageSource {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            guard let asset = result.firstObject else { return }
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 800, height: 800), contentMode: .aspectFill, options: opts) { img, _ in
                if let img { DispatchQueue.main.async { self.image = img; self.item.loadedImage = img } }
            }
        }
    }
}

// MARK: - ConfirmedTextLayerView

struct ConfirmedTextLayerView: View {
    @Binding var item: CassetteTextLayer
    let cassetteFrame: CGRect
    let onTap: () -> Void

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var magnifyDelta: CGFloat = 1.0
    @GestureState private var rotateDelta: Angle = .zero
    @State private var squareSize: CGFloat = 80

    var body: some View {
        Text(item.text)
            .font(item.font.swiftUIFont(size: item.size.pointSize))
            .foregroundColor(item.color)
            .padding(8)
            .fixedSize()
            .background(GeometryReader { geo in
                Color.clear.onAppear {
                    squareSize = max(geo.size.width, geo.size.height)
                }
            })
            .frame(minWidth: squareSize, minHeight: squareSize)
            .contentShape(Rectangle())
            .scaleEffect(item.scale * magnifyDelta)
            .rotationEffect(item.rotation + rotateDelta)
            .position(
                x: cassetteFrame.midX + item.offset.width + dragDelta.width,
                y: cassetteFrame.midY + item.offset.height + dragDelta.height
            )
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($dragDelta) { v, state, _ in state = v.translation }
                    .onEnded { v in
                        item.offset.width += v.translation.width
                        item.offset.height += v.translation.height
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($magnifyDelta) { v, state, _ in state = v }
                    .onEnded { v in item.scale = max(0.3, item.scale * v) }
            )
            .simultaneousGesture(
                RotationGesture()
                    .updating($rotateDelta) { v, state, _ in state = v }
                    .onEnded { v in item.rotation += v }
            )
            .onTapGesture { onTap() }
    }
}
