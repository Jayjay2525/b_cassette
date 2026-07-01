import SwiftUI
import Photos

// MARK: - Text Layer

struct CassetteTextLayer: Identifiable {
    let id = UUID()
    var text: String
    var font: CassetteFont
    var size: CGFloat
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

// 텍스트 크기: 슬라이더로 10~60pt 연속 조절
let textSizeRange: ClosedRange<CGFloat> = 10...60

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
    @State private var selectedTextSize: CGFloat = 24
    @State private var selectedTextColorHex: String = "FFFFFF"
    @State private var colorFromPicker = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var textDragOffset: CGSize = .zero
    @State private var textDragBase: CGSize = .zero
    @State private var textScale: CGFloat = 1.0
    @State private var textScaleBase: CGFloat = 1.0
    @State private var textRotation: Angle = .zero
    @State private var textRotationBase: Angle = .zero
    @State private var showColorPicker = false
    @State private var hideDimForColorPicker = false
    @State private var pickerSnapshot: UIImage? = nil
    @State private var confirmedTextItems: [CassetteTextLayer] = []
    @State private var editingLayerID: UUID? = nil
    @State private var cassetteFrame: CGRect = .zero
    @State private var editingTextSquare: CGFloat = 80
    @State private var cursorVisible: Bool = true
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

                // ── 숨겨진 TextEditor (멀티라인, 키보드용) ──
                if showTextEditor {
                    TextEditor(text: $textInput)
                        .focused($textFieldFocused)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .frame(width: 1, height: 1)
                        .opacity(0.001)
                        .scrollContentBackground(.hidden)
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
            if showTextEditor && keyboardHeight > 0 && !showColorPicker && !hideDimForColorPicker {
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

            // ── 텍스트 편집 floating done 버튼 (dim 위) ──
            if showTextEditor && keyboardHeight > 0 && !showColorPicker && !hideDimForColorPicker {
                VStack {
                    HStack {
                        Spacer()
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
                        .padding(.trailing, 24)
                        .padding(.top, 15)
                    }
                    Spacer()
                }
                .zIndex(18)
            }

            // ── 편집 중 텍스트 레이어 (어두운 오버레이 위, zIndex 18) ──
            if showTextEditor && !showColorPicker && !hideDimForColorPicker {
                let textColor = Color(hex: selectedTextColorHex)
                let bodyText = textInput.isEmpty ? " " : textInput
                (
                    Text(bodyText).foregroundColor(textColor)
                    + Text("|").foregroundColor(cursorVisible ? .white : .clear)
                )
                .font(selectedFont.swiftUIFont(size: selectedTextSize))
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

            // ── 텍스트 편집 툴바 (탭 버튼 하단이 키보드로부터 64pt 위 고정) ──
            if showTextEditor && keyboardHeight > 0 && !showColorPicker && !hideDimForColorPicker {
                VStack(spacing: 0) {
                    Spacer()
                    TextEditorToolbar(
                        selectedTab: $selectedTextTab,
                        selectedFont: $selectedFont,
                        selectedSize: $selectedTextSize,
                        selectedColorHex: $selectedTextColorHex,
                        colorFromPicker: $colorFromPicker,
                        onPickerTap: openColorPicker
                    )
                    .frame(maxWidth: .infinity)
                    Spacer().frame(height: keyboardHeight + 12)
                }
                .ignoresSafeArea()
                .zIndex(20)
            }

            // ── 컬러 피커 오버레이 ──
            if showColorPicker, let snap = pickerSnapshot {
                ColorPickerOverlay(
                    snapshot: snap,
                    selectedHex: $selectedTextColorHex,
                    onDone: { showColorPicker = false; colorFromPicker = true }
                )
                .ignoresSafeArea()
                .zIndex(99)
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
        .onChange(of: showTextEditor) {
            if showTextEditor {
                cursorVisible = true
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                    if !showTextEditor { timer.invalidate(); return }
                    cursorVisible.toggle()
                }
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
            // enter 등으로 키보드가 닫히면 텍스트 편집 종료 (텍스트 저장)
            if showTextEditor {
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
            }
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

    private func openColorPicker() {
        hideDimForColorPicker = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            pickerSnapshot = snapshotMainWindow()
            showColorPicker = true
            hideDimForColorPicker = false
        }
    }

    private func snapshotMainWindow() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { ctx in
            window.layer.render(in: ctx.cgContext)
        }
    }

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
                    .font(item.font.swiftUIFont(size: item.size * s))
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
    @Binding var selectedSize: CGFloat
    @Binding var selectedColorHex: String
    @Binding var colorFromPicker: Bool
    var onPickerTap: () -> Void = {}

    private let textColorHexes: [String] = [
        "FFFFFF", "000000",
        "FF0000", "FF7C00", "FFC500",
        "00C50D", "009CFF", "C300C8",
        "333333", "555555", "777777", "999999"
    ]

    var body: some View {
        VStack(spacing: 12) {
            // ── 탭 버튼 row (중앙 정렬, 72×40 rounded rect) ──
            HStack(spacing: 8) {
                tabButton("font", tab: .font)
                tabButton("size", tab: .size)
                tabButton("color", tab: .color)
            }

            // ── 탭 콘텐츠 (고정 높이로 탭 위치 안정) ──
            Group {
                switch selectedTab {
                case .font:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CassetteFont.allCases, id: \.self) { f in
                                fontChip(f)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                case .size:
                    TextSizeSlider(value: $selectedSize)
                        .padding(.horizontal, 16)
                case .color:
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // 컬러 피커 버튼 (배경: 현재 선택 컬러, 피커 사용 시 선택 stroke)
                            Button { onPickerTap() } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: selectedColorHex))
                                        .frame(width: 36, height: 36)
                                    Image("button_color_picker")
                                        .resizable()
                                        .frame(width: 36, height: 36)
                                }
                                .overlay(Circle().strokeBorder(Color.black, lineWidth: colorFromPicker ? 1 : 0))
                            }

                            ForEach(Array(textColorHexes.enumerated()), id: \.offset) { i, hex in
                                colorChip(hex, index: i)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(height: 44)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func tabButton(_ label: String, tab: TextEditTab) -> some View {
        let isSelected = selectedTab == tab
        Button { selectedTab = tab } label: {
            Text(label)
                .font(.appBody)
                .foregroundColor(isSelected ? .appBlack : .white)
                .frame(width: 72, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white : Color(hex: "B3B3B3"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.black : Color.clear, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func fontChip(_ f: CassetteFont) -> some View {
        let isSelected = selectedFont == f
        Button { selectedFont = f } label: {
            Text(f.displayName)
                .font(f.swiftUIFont(size: 16))
                .foregroundColor(isSelected ? .appBlack : .white)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white : Color(hex: "B3B3B3"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.black : Color.clear, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func colorChip(_ hex: String, index: Int) -> some View {
        let isSelected = selectedColorHex.uppercased() == hex.uppercased() && !colorFromPicker
        let isWhite = index == 0
        Button { selectedColorHex = hex; colorFromPicker = false } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: hex))
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "CCCCCC"), lineWidth: isWhite ? 1 : 0))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black, lineWidth: isSelected ? 1 : 0))
        }
    }
}

// MARK: - TextSizeSlider

struct TextSizeSlider: View {
    @Binding var value: CGFloat

    private let trackWidth: CGFloat = 324
    private let handleWidth: CGFloat = 14
    private let minVal: CGFloat = 10
    private let maxVal: CGFloat = 60

    // ZStack 중앙 기준 핸들 offset
    private var handleOffset: CGFloat {
        let fraction = (value - minVal) / (maxVal - minVal)
        return (fraction - 0.5) * (trackWidth - handleWidth)
    }

    var body: some View {
        ZStack {
            Image("text_size_graph")
                .resizable()
                .frame(width: trackWidth, height: 20)

            Image("text_size_handle")
                .resizable()
                .frame(width: handleWidth, height: 28)
                .offset(x: handleOffset)
        }
        .frame(width: trackWidth, height: 40)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    // gesture.location.x는 ZStack 내 0-based 좌표
                    let clamped = min(max(gesture.location.x, handleWidth / 2), trackWidth - handleWidth / 2)
                    let fraction = (clamped - handleWidth / 2) / (trackWidth - handleWidth)
                    value = (minVal + fraction * (maxVal - minVal)).rounded()
                }
        )
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
            .font(item.font.swiftUIFont(size: item.size))
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

// MARK: - ColorPickerOverlay

struct ColorPickerOverlay: View {
    let snapshot: UIImage
    @Binding var selectedHex: String
    var onDone: () -> Void

    @State private var location: CGPoint = CGPoint(
        x: UIScreen.main.bounds.midX,
        y: UIScreen.main.bounds.midY
    )

    private let loupeSize: CGFloat = 80
    private let dotSize: CGFloat = 4

    var body: some View {
        let screenSize = UIScreen.main.bounds.size
        ZStack {
            Image(uiImage: snapshot)
                .resizable()
                .ignoresSafeArea()

            // 전체 화면 드래그 제스처
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { v in
                            location = v.location
                            if let hex = snapshot.hexColor(at: v.location, screenSize: screenSize) {
                                selectedHex = hex
                            }
                        }
                        .onEnded { _ in onDone() }
                )

            // 2×2 흰 점
            Rectangle()
                .fill(Color.white)
                .frame(width: dotSize, height: dotSize)
                .position(location)
                .allowsHitTesting(false)

            // 루페 (점 위로 고정 offset)
            let loupeY = location.y - loupeSize / 2 - dotSize / 2 - 20
            let clampedLoupeY = max(loupeY, loupeSize / 2 + 60)
            ZStack {
                if let cropped = snapshot.magnifiedRegion(
                    around: location, screenSize: screenSize,
                    zoomFactor: 4, displaySize: loupeSize
                ) {
                    Image(uiImage: cropped)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: loupeSize, height: loupeSize)
                        .clipShape(Circle())
                }
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .frame(width: loupeSize, height: loupeSize)
                // 중앙 십자선
                Group {
                    Rectangle().frame(width: 1, height: 14)
                    Rectangle().frame(width: 14, height: 1)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .position(x: location.x, y: clampedLoupeY)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - UIImage pixel helpers

extension UIImage {
    func hexColor(at screenPoint: CGPoint, screenSize: CGSize) -> String? {
        let scaleX = size.width / screenSize.width
        let scaleY = size.height / screenSize.height
        let px = screenPoint.x * scaleX
        let py = screenPoint.y * scaleY

        // UIKit 컨텍스트 사용: 좌표계 뒤집힘을 UIKit이 자동 처리
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), true, 1)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.translateBy(x: -px, y: -py)
        draw(at: .zero)
        guard let ptr = ctx.data?.bindMemory(to: UInt8.self, capacity: 4) else { return nil }
        // UIKit 컨텍스트는 iOS(ARM, little-endian)에서 BGRA 순서
        return String(format: "%02X%02X%02X", ptr[2], ptr[1], ptr[0])
    }

    func magnifiedRegion(around screenPoint: CGPoint, screenSize: CGSize,
                         zoomFactor: CGFloat, displaySize: CGFloat) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let scaleX = CGFloat(cgImage.width) / screenSize.width
        let scaleY = CGFloat(cgImage.height) / screenSize.height
        let cropPtSize = displaySize / zoomFactor
        let cropRect = CGRect(
            x: (screenPoint.x - cropPtSize / 2) * scaleX,
            y: (screenPoint.y - cropPtSize / 2) * scaleY,
            width: cropPtSize * scaleX,
            height: cropPtSize * scaleY
        )
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}
