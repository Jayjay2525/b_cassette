import SwiftUI
import Photos

// MARK: - Text Layer

struct CassetteTextLayer: Identifiable {
    var id: UUID
    var text: String
    var font: CassetteFont
    var size: CGFloat
    var colorHex: String
    var offset: CGSize
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero

    var color: Color { Color(hex: colorHex) }

    init(id: UUID = UUID(), text: String, font: CassetteFont, size: CGFloat, colorHex: String, offset: CGSize, scale: CGFloat = 1.0, rotation: Angle = .zero) {
        self.id = id
        self.text = text
        self.font = font
        self.size = size
        self.colorHex = colorHex
        self.offset = offset
        self.scale = scale
        self.rotation = rotation
    }
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
    @State private var selectedStickerName: String? = nil
    @State private var selectedLabelName: String? = nil
    @State private var previewImageLayer: CassetteImageLayer? = nil
    @State private var confirmedImageItems: [CassetteImageLayer] = []
    @State private var isDesignRestored: Bool = false
    @State private var activeImageLayerID: UUID? = nil
    @State private var orderedLayerIDs: [UUID] = []       // bottom→top z-order
    @State private var imageCreationOrder: [UUID] = []    // for display naming
    @State private var textCreationOrder: [UUID] = []     // for display naming
    @State private var editingLayerZPos: Int? = nil       // z-pos when re-editing text

    // ── Text 편집 ──
    @State private var showTextEditor = false
    @State private var textInput = ""
    @State private var selectedTextTab: TextEditTab = .font
    @State private var selectedFont: CassetteFont = .inspiration
    @State private var selectedTextSize: CGFloat = 35
    @State private var selectedTextColorHex: String = "000000"
    @State private var colorFromPicker = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var textDragOffset: CGSize = CGSize(width: 0, height: 30)
    @State private var textDragBase: CGSize = CGSize(width: 0, height: 30)
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
                VStack(spacing: 12) {
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
                .padding(.bottom, 10)

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
                            let f = geo.frame(in: .named("outerZStack"))
                            if f.width > 0 { cassetteFrame = f }
                        }.onChange(of: geo.frame(in: .named("outerZStack"))) {
                            let f = geo.frame(in: .named("outerZStack"))
                            if f.width > 0 { cassetteFrame = f }
                        }
                    }
                )


                Spacer()
            }

            // ── 레이어 패널 (zIndex 17 — 이미지 레이어보다 위) ──
            if !showStickerPanel && !showCassettePanel && !showTextEditor {
                VStack(spacing: 0) {
                    Spacer().frame(height: cassetteFrame.maxY + 30)
                    LayerPanelView(
                        orderedLayerIDs: $orderedLayerIDs,
                        confirmedImageItems: $confirmedImageItems,
                        confirmedTextItems: $confirmedTextItems,
                        imageCreationOrder: imageCreationOrder,
                        textCreationOrder: textCreationOrder,
                        cassetteColorName: cassetteData.selectedCassetteColor,
                        onDeleteLayer: { id in
                            confirmedImageItems.removeAll { $0.id == id }
                            confirmedTextItems.removeAll { $0.id == id }
                            orderedLayerIDs.removeAll { $0 == id }
                        },
                        onTapBackground: {
                            withAnimation(.easeInOut(duration: 0.25)) { showCassettePanel = true }
                        },
                        onTapLayer: { id in
                            if let idx = confirmedImageItems.firstIndex(where: { $0.id == id }) {
                                let tapped = confirmedImageItems[idx]
                                editingLayerZPos = orderedLayerIDs.firstIndex(of: tapped.id)
                                confirmedImageItems.remove(at: idx)
                                orderedLayerIDs.removeAll { $0 == tapped.id }
                                previewImageLayer = tapped
                                selectedStickerPhoto = tapped.photo
                                stickerStyle = tapped.maskStyle
                                if tapped.isLabel {
                                    stickerTab = .label
                                } else if case .bundleAsset = tapped.photo.imageSource {
                                    stickerTab = .sticker
                                } else {
                                    stickerTab = .image
                                }
                                withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel = true }
                            } else if let idx = confirmedTextItems.firstIndex(where: { $0.id == id }) {
                                enterTextEdit(at: idx)
                            }
                        }
                    )
                    Spacer()
                }
                .zIndex(18)
            }

            // ── 하단 툴 버튼 + done (이미지 레이어보다 위) ──
            VStack {
                Spacer()
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
                        toolButton(icon: "button_decorate") {
                            withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel.toggle() }
                        }
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
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
                .opacity(showTextEditor || showStickerPanel ? 0 : 1)
                .allowsHitTesting(!showTextEditor && !showStickerPanel)
            }
            .zIndex(18)

            // ── cassette 패널 열려있을 때 뒤쪽 탭으로 닫기 ──
            if showCassettePanel {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCassettePanel = false
                        }
                    }
                    .zIndex(9)
            }

            // ── 스티커 style 버튼 (label 탭이 아닐 때만) ──
            if showStickerPanel && stickerTab != .label {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        styleButton(icon: "button_background", style: .background)
                        styleButton(icon: "button_foreground", style: .foreground)
                    }
                    .padding(.bottom, 353 + 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
                .transition(.opacity)
                .zIndex(20)
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
                .zIndex(20)
            }

            // ── 텍스트 편집 모드 어두운 오버레이 (확정 레이어들 위, 편집 텍스트 아래) ──
            if showTextEditor && keyboardHeight > 0 && !showColorPicker && !hideDimForColorPicker {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .zIndex(18)
                    .allowsHitTesting(false)
            }

            // ── 레이어들 (orderedLayerIDs 순서로 z-order 결정, last=top) ──
            ForEach(orderedLayerIDs, id: \.self) { id in
                if let idx = confirmedImageItems.firstIndex(where: { $0.id == id }) {
                    ConfirmedImageLayerView(item: $confirmedImageItems[idx], cassetteFrame: cassetteFrame, activeLayerID: $activeImageLayerID) {
                        let tapped = confirmedImageItems[idx]
                        editingLayerZPos = orderedLayerIDs.firstIndex(of: tapped.id)
                        confirmedImageItems.remove(at: idx)
                        orderedLayerIDs.removeAll { $0 == tapped.id }
                        previewImageLayer = tapped
                        selectedStickerPhoto = tapped.photo
                        stickerStyle = tapped.maskStyle
                        if tapped.isLabel {
                            stickerTab = .label
                        } else if case .bundleAsset = tapped.photo.imageSource {
                            stickerTab = .sticker
                        } else {
                            stickerTab = .image
                        }
                        withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel = true }
                    }
                    .allowsHitTesting(!showTypePopup && !showStickerPanel && !showTextEditor)
                } else if let idx = confirmedTextItems.firstIndex(where: { $0.id == id }) {
                    ConfirmedTextLayerView(item: $confirmedTextItems[idx], cassetteFrame: cassetteFrame) {
                        enterTextEdit(at: idx)
                    }
                    .allowsHitTesting(!showTypePopup && !showTextEditor && !showStickerPanel)
                }
            }
            .zIndex(14)

            // ── 카세트 패널 열릴 때 프리뷰 레이어 터치 차단 ──
            if showCassettePanel, cassetteFrame.width > 0 {
                Color.clear
                    .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                    .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
                    .contentShape(Rectangle())
                    .zIndex(15)
            }

            // ── 스티커 프리뷰 레이어 ──
            if let _ = previewImageLayer {
                ConfirmedImageLayerView(item: Binding(
                    get: { previewImageLayer! },
                    set: { previewImageLayer = $0 }
                ), cassetteFrame: cassetteFrame, activeLayerID: $activeImageLayerID)
                .id(previewImageLayer?.id)
                .allowsHitTesting(!showTypePopup)
                .zIndex(14)
            }

            // ── 카세트 표면 굴곡 쉐이딩 오버레이 ──
            if cassetteFrame.width > 0 {
                Image("cassette_multiply")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                    .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
                    .blendMode(.plusDarker)
                    .allowsHitTesting(false)
                    .zIndex(16)

                // ── bolts: 모든 레이어 위에 항상 최상단 ──
                Image("bolts")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                    .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
                    .allowsHitTesting(false)
                    .zIndex(18)
            }

            // ── 텍스트 편집 floating done 버튼 (dim 위) ──
            if showTextEditor && keyboardHeight > 0 && !showColorPicker && !hideDimForColorPicker {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            if !textInput.isEmpty {
                                let saved = CassetteTextLayer(
                                    id: editingLayerID ?? UUID(),
                                    text: textInput,
                                    font: selectedFont,
                                    size: selectedTextSize,
                                    colorHex: selectedTextColorHex,
                                    offset: textDragOffset,
                                    scale: textScale,
                                    rotation: textRotation
                                )
                                confirmedTextItems.append(saved)
                                if let zPos = editingLayerZPos {
                                    orderedLayerIDs.insert(saved.id, at: min(zPos, orderedLayerIDs.count))
                                } else {
                                    orderedLayerIDs.append(saved.id)
                                }
                                if !textCreationOrder.contains(saved.id) { textCreationOrder.append(saved.id) }
                            }
                            textInput = ""
                            textDragOffset = CGSize(width: 0, height: 30)
                            textDragBase = .zero
                            textScale = 1.0
                            textScaleBase = 1.0
                            textRotation = .zero
                            textRotationBase = .zero
                            editingLayerID = nil
                            editingLayerZPos = nil
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
                editingTextLayerView
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
                    selectedPhoto: $selectedStickerPhoto,
                    photos: cassetteData.selectedPhotos,
                    selectedStickerName: $selectedStickerName,
                    selectedLabelName: $selectedLabelName,
                    onSelect: { photo in
                        if let photo {
                            previewImageLayer = CassetteImageLayer(photo: photo, maskStyle: stickerStyle)
                        } else {
                            previewImageLayer = nil
                        }
                    },
                    onSelectSticker: { name in
                        if let name {
                            let dummyPhoto = BCutPhoto(id: UUID(), imageSource: .bundleAsset(name), isBCut: false, takenAt: Date())
                            previewImageLayer = CassetteImageLayer(photo: dummyPhoto, maskStyle: stickerStyle)
                        } else {
                            previewImageLayer = nil
                        }
                    },
                    onSelectLabel: { name in
                        if let name {
                            let dummyPhoto = BCutPhoto(id: UUID(), imageSource: .bundleAsset(name), isBCut: false, takenAt: Date())
                            var layer = CassetteImageLayer(photo: dummyPhoto, maskStyle: .foreground)
                            layer.isLabel = true
                            previewImageLayer = layer
                        } else {
                            previewImageLayer = nil
                        }
                    },
                    onCancel: {
                        previewImageLayer = nil
                        selectedStickerPhoto = nil
                        selectedStickerName = nil
                        selectedLabelName = nil
                        withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel = false }
                    },
                    onDone: {
                        if let layer = previewImageLayer {
                            confirmedImageItems.append(layer)
                            if let zPos = editingLayerZPos {
                                orderedLayerIDs.insert(layer.id, at: min(zPos, orderedLayerIDs.count))
                            } else {
                                orderedLayerIDs.append(layer.id)
                            }
                            if !imageCreationOrder.contains(layer.id) { imageCreationOrder.append(layer.id) }
                        }
                        previewImageLayer = nil
                        selectedStickerPhoto = nil
                        selectedStickerName = nil
                        selectedLabelName = nil
                        editingLayerZPos = nil
                        withAnimation(.easeInOut(duration: 0.25)) { showStickerPanel = false }
                    }
                )
                .transition(.move(edge: .bottom))
                .zIndex(20)

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
                    let saved = CassetteTextLayer(
                        id: editingLayerID ?? UUID(),
                        text: textInput,
                        font: selectedFont,
                        size: selectedTextSize,
                        colorHex: selectedTextColorHex,
                        offset: textDragOffset,
                        scale: textScale,
                        rotation: textRotation
                    )
                    confirmedTextItems.append(saved)
                    if let zPos = editingLayerZPos {
                        orderedLayerIDs.insert(saved.id, at: min(zPos, orderedLayerIDs.count))
                    } else {
                        orderedLayerIDs.append(saved.id)
                    }
                    if !textCreationOrder.contains(saved.id) { textCreationOrder.append(saved.id) }
                }
                textInput = ""
                textDragOffset = CGSize(width: 0, height: 30)
                textDragBase = .zero
                textScale = 1.0
                textScaleBase = 1.0
                textRotation = .zero
                textRotationBase = .zero
                editingLayerID = nil
                editingLayerZPos = nil
                showTextEditor = false
            }
        }
        .onChange(of: stickerStyle) { previewImageLayer?.maskStyle = stickerStyle }
        .onAppear {
            if !isDesignRestored {
                confirmedImageItems = cassetteData.draftImageLayers
                confirmedTextItems = cassetteData.draftTextLayers
                orderedLayerIDs = cassetteData.draftOrderedLayerIDs
                imageCreationOrder = cassetteData.draftImageCreationOrder
                textCreationOrder = cassetteData.draftTextCreationOrder
                // orderedLayerIDs가 없으면 기존 draft 순서 기반으로 재구성
                if orderedLayerIDs.isEmpty {
                    orderedLayerIDs = confirmedImageItems.map(\.id) + confirmedTextItems.map(\.id)
                    imageCreationOrder = confirmedImageItems.map(\.id)
                    textCreationOrder = confirmedTextItems.map(\.id)
                }
                isDesignRestored = true
            }
        }
        .onDisappear {
            cassetteData.draftImageLayers = confirmedImageItems
            cassetteData.draftTextLayers = confirmedTextItems
            cassetteData.draftOrderedLayerIDs = orderedLayerIDs
            cassetteData.draftImageCreationOrder = imageCreationOrder
            cassetteData.draftTextCreationOrder = textCreationOrder
        }
        .alert("Leave without saving?", isPresented: $showExitAlert) {
            Button("leave", role: .destructive) {
                cassetteData.draftImageLayers = []
                cassetteData.draftTextLayers = []
                cassetteData.shouldDismiss = true
            }
            Button("cancel", role: .cancel) { }
        } message: {
            Text("Your cassette won't be saved.")
        }
    }

    // MARK: - 툴 버튼

    @ViewBuilder private var editingTextLayerView: some View {
        let textColor = Color(hex: selectedTextColorHex)
        let bodyText = textInput.isEmpty ? " " : textInput
        (
            Text(bodyText).foregroundColor(textColor)
            + Text("|").foregroundColor(cursorVisible ? .white : .clear).font(.system(size: selectedTextSize, weight: .ultraLight))
        )
        .font(selectedFont.swiftUIFont(size: selectedTextSize))
        .padding(8)
        .fixedSize()
        .background(SizeReader { editingTextSquare = max($0.width, $0.height) })
        .frame(minWidth: editingTextSquare, minHeight: editingTextSquare)
        .contentShape(Rectangle())
        .scaleEffect(textScale)
        .rotationEffect(textRotation)
        .position(x: cassetteFrame.midX + textDragOffset.width, y: cassetteFrame.midY + textDragOffset.height)
        .gesture(DragGesture()
            .onChanged { v in textDragOffset = CGSize(width: textDragBase.width + v.translation.width, height: textDragBase.height + v.translation.height) }
            .onEnded { _ in textDragBase = textDragOffset })
        .simultaneousGesture(MagnificationGesture()
            .onChanged { v in textScale = textScaleBase * v }
            .onEnded { _ in textScaleBase = textScale })
        .simultaneousGesture(RotationGesture()
            .onChanged { v in textRotation = textRotationBase + v }
            .onEnded { _ in textRotationBase = textRotation })
    }

    private func enterTextEdit(at idx: Int) {
        if showTextEditor && !textInput.isEmpty {
            let saved = CassetteTextLayer(text: textInput, font: selectedFont, size: selectedTextSize, colorHex: selectedTextColorHex, offset: textDragOffset, scale: textScale, rotation: textRotation)
            confirmedTextItems.append(saved)
            orderedLayerIDs.append(saved.id)
            if !textCreationOrder.contains(saved.id) { textCreationOrder.append(saved.id) }
        }
        let tapped = confirmedTextItems[idx]
        editingLayerID = tapped.id
        editingLayerZPos = orderedLayerIDs.firstIndex(of: tapped.id)
        textInput = tapped.text
        selectedFont = tapped.font
        selectedTextSize = tapped.size
        selectedTextColorHex = tapped.colorHex
        textDragOffset = tapped.offset
        textDragBase = tapped.offset
        textScale = tapped.scale
        textScaleBase = tapped.scale
        textRotation = tapped.rotation
        textRotationBase = tapped.rotation
        confirmedTextItems.remove(at: idx)
        orderedLayerIDs.removeAll { $0 == tapped.id }
        showTextEditor = true
        textFieldFocused = true
    }

    @ViewBuilder
    private func styleButton(icon: String, style: StickerStyle) -> some View {
        let isSelected = stickerStyle == style
        Button { stickerStyle = style } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : Color.appGray)
                    .frame(width: 55, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.black : Color.clear, lineWidth: 1)
                    )
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
        }
    }

    private func toolButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.appWhite)
                    .frame(width: 56, height: 56)
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
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
            applyMask: false,
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

            // ── 이미지 레이어 (스타일별 mask) ──
            let s = width / baseWidth
            let bgImages = imageLayers.filter { !$0.isLabel && $0.maskStyle == .background }
            let fgImages = imageLayers.filter { !$0.isLabel && $0.maskStyle == .foreground }
            let labelImages = imageLayers.filter { $0.isLabel }
            if !bgImages.isEmpty {
                ZStack {
                    ForEach(bgImages) { item in
                        if let img = item.loadedImage {
                            let cw: CGFloat = item.cropShape == .rect ? 120 * s : 160 * s
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cw, height: 160 * s)
                                .modifier(CropShapeClip(shape: item.cropShape))
                                .scaleEffect(item.scale)
                                .rotationEffect(item.rotation)
                                .offset(x: item.offset.width * s, y: item.offset.height * s)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask {
                    Image("cassette_mask_outside").resizable().scaledToFit()
                }
            }
            if !fgImages.isEmpty {
                ZStack {
                    ForEach(fgImages) { item in
                        if let img = item.loadedImage {
                            let cw: CGFloat = item.cropShape == .rect ? 120 * s : 160 * s
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cw, height: 160 * s)
                                .modifier(CropShapeClip(shape: item.cropShape))
                                .scaleEffect(item.scale)
                                .rotationEffect(item.rotation)
                                .offset(x: item.offset.width * s, y: item.offset.height * s)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask {
                    Image("cassette_mask_center").resizable().scaledToFit()
                }
            }
            // ── 레이블 레이어 (고정 크기/위치, cassette_mask_center로 클립) ──
            if !labelImages.isEmpty {
                ZStack {
                    ForEach(labelImages) { item in
                        if let img = item.loadedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: width)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask {
                    Image("cassette_mask_center").resizable().scaledToFit()
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
        ZStack(alignment: .bottom) {
        VStack(alignment: .center, spacing: 0) {
            // drag indicator

            // ── 타이틀 ──
            Text("cassette type")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .padding(.bottom, 16)
                .padding(.top, 16)

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

            Spacer()
        }

        // ── done 버튼 floating ──
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

        } // ZStack
        .frame(height: 387)
        .clipped()
        .background(
            Color.appLightGray
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

enum StickerTab { case image, sticker, label }
enum StickerStyle { case background, foreground }
enum CropShape { case rect, square, circle
    var next: CropShape {
        switch self {
        case .rect: return .square
        case .square: return .circle
        case .circle: return .rect
        }
    }
}

let builtinLabels: [String] = [
    "sticker_whole_1", "sticker_whole_2", "sticker_whole_3",
    "sticker_whole_4", "sticker_whole_5", "sticker_whole_6",
    "sticker_whole_7", "sticker_top_1", "sticker_top_2",
    "sticker_bot_1"
]

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

// MARK: - Decorate 패널

struct StickerEditPanel: View {
    @Binding var selectedTab: StickerTab
    @Binding var selectedPhoto: BCutPhoto?
    let photos: [BCutPhoto]
    @Binding var selectedStickerName: String?
    @Binding var selectedLabelName: String?
    var onSelect: (BCutPhoto?) -> Void = { _ in }
    var onSelectSticker: (String?) -> Void = { _ in }
    var onSelectLabel: (String?) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onDone: () -> Void

    private let photoColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {

                // ── 탭 버튼 ──
                HStack(spacing: 12) {
                    tabButton(icon: "button_image", tab: .image)
                    tabButton(icon: "button_emoji", tab: .sticker)
                    tabButton(icon: "button_foreground", tab: .label)
                }
                .padding(.bottom, 14)
                .padding(.top, 16)

                Divider()

                // ── 탭 콘텐츠 ──
                switch selectedTab {
                case .image:
                    Text("b-cut from film")
                        .font(.appBody)
                        .foregroundColor(.appDarkGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: photoColumns, spacing: 4) {
                            ForEach(photos) { photo in
                                let isSelected = selectedPhoto?.id == photo.id
                                StickerPhotoCell(photo: photo, isSelected: isSelected)
                                    .onTapGesture {
                                        let next: BCutPhoto? = isSelected ? nil : photo
                                        selectedPhoto = next
                                        if next != nil {
                                            selectedStickerName = nil
                                            selectedLabelName = nil
                                        }
                                        onSelect(next)
                                    }
                            }
                        }
                        .padding(.bottom, 70)
                    }
                    .frame(maxHeight: .infinity)

                case .sticker:
                    Text("sticker")
                        .font(.appBody)
                        .foregroundColor(.appDarkGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        Text("coming soon")
                            .font(.appMicro)
                            .foregroundColor(.appGray)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }
                    .frame(maxHeight: .infinity)

                case .label:
                    Text("label")
                        .font(.appBody)
                        .foregroundColor(.appDarkGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: photoColumns, spacing: 4) {
                            ForEach(builtinLabels, id: \.self) { name in
                                let isSelected = selectedLabelName == name
                                ZStack {
                                    Color.clear
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            Image(name)
                                                .resizable()
                                                .scaledToFit()
                                                .padding(8)
                                        )
                                        .overlay(isSelected ? Color.black.opacity(0.15) : Color.clear)
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
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(isSelected ? Color.appBlack : Color.clear, lineWidth: 1)
                                )
                                .onTapGesture {
                                    let next: String? = isSelected ? nil : name
                                    selectedLabelName = next
                                    if next != nil {
                                        selectedPhoto = nil
                                        selectedStickerName = nil
                                    }
                                    onSelectLabel(next)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 70)
                    }
                    .frame(maxHeight: .infinity)
                }
            }

            // ── done 버튼 ──
            let canDone = selectedPhoto != nil || selectedStickerName != nil || selectedLabelName != nil
            Button { onDone() } label: {
                Text("done")
                    .font(.appBody)
                    .foregroundColor(.appWhite)
                    .frame(width: 201, height: 48)
                    .background(Capsule().fill(canDone ? Color.appDarkGray : Color.appGray))
            }
            .disabled(!canDone)
            .padding(.bottom, 11)

        }
        .frame(height: 353)
        .background(Color.appWhite)
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
    }

    @ViewBuilder
    private func tabButton(icon: String, tab: StickerTab) -> some View {
        let isSelected = selectedTab == tab
        Button { selectedTab = tab } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : Color.appGray)
                    .frame(width: 72, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? Color.black : Color.clear, lineWidth: 1)
                    )
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
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
            .aspectRatio(3.0/4.0, contentMode: .fit)
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
            .overlay(RoundedRectangle(cornerRadius: 0).strokeBorder(isSelected ? Color.appBlack : Color.clear, lineWidth: 1))
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
        "000000", "FFFFFF",
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

                            Rectangle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 1, height: 23)
                                .padding(.horizontal, 4)

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
                        .fill(isSelected ? Color.white : Color.appGray)
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
                        .fill(isSelected ? Color.white : Color.appGray)
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
        let isBlack = index == 0
        let strokeColor: Color = isBlack ? .white : .black
        Button { selectedColorHex = hex; colorFromPicker = false } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: hex))
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(strokeColor, lineWidth: isSelected ? 1 : 0))
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
    var maskStyle: StickerStyle = .background
    var isLabel: Bool = false   // label은 고정 위치/크기, gesture 없음
    var cropShape: CropShape = .rect
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
    var loadedImage: UIImage? = nil
}

// MARK: - CropShapeClip

private struct CropShapeClip: ViewModifier {
    let shape: CropShape
    func body(content: Content) -> some View {
        switch shape {
        case .rect:   content.clipped()
        case .square: content.clipped()
        case .circle: content.clipShape(Circle())
        }
    }
}

// MARK: - ConfirmedImageLayerView

struct ConfirmedImageLayerView: View {
    @Binding var item: CassetteImageLayer
    let cassetteFrame: CGRect
    @Binding var activeLayerID: UUID?
    var onTap: (() -> Void)? = nil

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var magnifyDelta: CGFloat = 1.0
    @GestureState private var rotateDelta: Angle = .zero
    @State private var image: UIImage? = nil

    private var isGestureActive: Bool {
        dragDelta != .zero || magnifyDelta != 1.0 || rotateDelta.radians != 0
    }

    var body: some View {
        let isBundleAsset: Bool = {
            if case .bundleAsset = item.photo.imageSource { return true }
            return false
        }()
        let isRegularImage = !isBundleAsset && !item.isLabel
        let cropW: CGFloat = (isRegularImage && item.cropShape == .rect) ? 120 : 160
        let cropH: CGFloat = 160
        let baseW: CGFloat = isBundleAsset ? cassetteFrame.width : cropW
        let baseH: CGFloat = isBundleAsset ? cassetteFrame.height : cropH

        if item.isLabel {
            // label: 고정 위치/크기, gesture 없음
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                } else {
                    Color.clear
                        .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                }
            }
            .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
            .mask {
                if cassetteFrame.width > 0 {
                    Image("cassette_mask_center")
                        .resizable()
                        .scaledToFit()
                        .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                        .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
                } else {
                    Color.white
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .onAppear { loadImage() }
        } else {
            // 일반 이미지/스티커: 이동/확대/회전 가능
            Group {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: baseW, height: baseH)
                        .modifier(CropShapeClip(shape: isRegularImage ? item.cropShape : .rect))
                } else {
                    Color.appGray.opacity(0.3)
                        .frame(width: baseW, height: baseH)
                }
            }
            .scaleEffect(item.scale * magnifyDelta)
            .rotationEffect(item.rotation + rotateDelta)
            .position(
                x: cassetteFrame.midX + item.offset.width + dragDelta.width,
                y: cassetteFrame.midY + item.offset.height + dragDelta.height
            )
            .mask {
                if cassetteFrame.width > 0 {
                    let maskName = item.maskStyle == .background ? "cassette_mask_outside" : "cassette_mask_center"
                    Image(maskName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                        .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
                } else {
                    Color.white
                }
            }
            .allowsHitTesting(activeLayerID == nil || activeLayerID == item.id)
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
            .onChange(of: isGestureActive) { _, active in
                if active {
                    if activeLayerID == nil { activeLayerID = item.id }
                } else {
                    if activeLayerID == item.id { activeLayerID = nil }
                }
            }
            .onTapGesture {
                if isRegularImage && onTap == nil {
                    // 프리뷰 중: crop 순환
                    item.cropShape = item.cropShape.next
                } else {
                    onTap?()
                }
            }
            .onAppear { loadImage() }
        }
    }

    func loadImage() {
        // 이미 캐시된 이미지 있으면 즉시 사용 (재렌더 시 깜빡임 방지)
        if let cached = item.loadedImage {
            image = cached
            return
        }
        if case .bundleAsset(let name) = item.photo.imageSource,
           let img = UIImage(named: name) {
            image = img
            item.loadedImage = img
            return
        }
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
            .mask {
                if cassetteFrame.width > 0 {
                    Image("cassette_mask_outside")
                        .resizable()
                        .scaledToFit()
                        .frame(width: cassetteFrame.width, height: cassetteFrame.height)
                        .position(x: cassetteFrame.midX, y: cassetteFrame.midY)
                } else {
                    Color.white
                }
            }
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

// MARK: - LayerPanelView

// MARK: - SizeReader

private struct SizeReader: View {
    let onChange: (CGSize) -> Void
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { onChange(geo.size) }
                .onChange(of: geo.size) { _, s in onChange(s) }
        }
    }
}

struct LayerPanelView: View {
    @Binding var orderedLayerIDs: [UUID]
    @Binding var confirmedImageItems: [CassetteImageLayer]
    @Binding var confirmedTextItems: [CassetteTextLayer]
    let imageCreationOrder: [UUID]
    let textCreationOrder: [UUID]
    let cassetteColorName: String
    var onDeleteLayer: (UUID) -> Void
    var onTapBackground: () -> Void
    var onTapLayer: (UUID) -> Void

    @State private var draggedID: UUID? = nil
    @State private var dragStartIndex: Int? = nil
    @State private var lastDragOffset: CGFloat = 0

    private enum LayerInfo {
        case image(n: Int, thumb: UIImage?)
        case sticker(n: Int, thumb: UIImage?)
        case label(n: Int, thumb: UIImage?)
        case text(n: Int, content: String)
        case unknown
    }

    private func layerInfo(for id: UUID) -> LayerInfo {
        if let item = confirmedImageItems.first(where: { $0.id == id }) {
            let thumb = item.loadedImage
            if item.isLabel {
                let labelIDs = imageCreationOrder.filter { sid in
                    confirmedImageItems.first(where: { $0.id == sid })?.isLabel ?? false
                }
                let n = (labelIDs.firstIndex(of: id) ?? 0) + 1
                return .label(n: n, thumb: thumb)
            } else if case .bundleAsset = item.photo.imageSource {
                let stickerIDs = imageCreationOrder.filter { sid in
                    guard let it = confirmedImageItems.first(where: { $0.id == sid }) else { return false }
                    if it.isLabel { return false }
                    if case .bundleAsset = it.photo.imageSource { return true }
                    return false
                }
                let n = (stickerIDs.firstIndex(of: id) ?? 0) + 1
                return .sticker(n: n, thumb: thumb)
            } else {
                let imageIDs = imageCreationOrder.filter { sid in
                    guard let it = confirmedImageItems.first(where: { $0.id == sid }) else { return false }
                    if it.isLabel { return false }
                    if case .bundleAsset = it.photo.imageSource { return false }
                    return true
                }
                let n = (imageIDs.firstIndex(of: id) ?? 0) + 1
                return .image(n: n, thumb: thumb)
            }
        } else if let idx = textCreationOrder.firstIndex(of: id) {
            let content = confirmedTextItems.first(where: { $0.id == id })?.text ?? ""
            return .text(n: idx + 1, content: content)
        }
        return .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("• layers")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .padding(.bottom, 20)

            // 레이어 목록 + cassette background — 최대 5행 스크롤
            let reversedIDs = Array(orderedLayerIDs.reversed())
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(reversedIDs, id: \.self) { id in
                        layerRow(id: id, isBackground: false)
                        Rectangle()
                            .fill(Color.appGray)
                            .frame(height: 1)
                            .padding(.vertical, 12)
                    }
                    backgroundRow
                }
            }
            .frame(height: 212)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func layerRow(id: UUID, isBackground: Bool) -> some View {
        let isDragging = draggedID == id
        HStack(spacing: 0) {
            // 핸들
            Image("button_handle")
                .resizable()
                .frame(width: 16, height: 16)
                .opacity(isBackground ? 0.3 : 1)
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .global)
                        .onChanged { v in
                            if draggedID != id {
                                draggedID = id
                                dragStartIndex = orderedLayerIDs.firstIndex(of: id)
                                lastDragOffset = 0
                            }
                            // 행 높이 약 44pt 기준으로 인덱스 이동
                            let rowHeight: CGFloat = 44
                            let dy = v.translation.height - lastDragOffset
                            if abs(dy) > rowHeight {
                                let dir = dy > 0 ? -1 : 1  // panel은 reversed 표시이므로 반전
                                if let fromIdx = orderedLayerIDs.firstIndex(of: id) {
                                    let toIdx = fromIdx + dir
                                    if toIdx >= 0 && toIdx < orderedLayerIDs.count {
                                        orderedLayerIDs.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: dir > 0 ? toIdx + 1 : toIdx)
                                        lastDragOffset = v.translation.height
                                    }
                                }
                            }
                        }
                        .onEnded { _ in
                            draggedID = nil
                            dragStartIndex = nil
                            lastDragOffset = 0
                        }
                )

            Spacer().frame(width: 12)

            // 레이어 타입별 콘텐츠
            switch layerInfo(for: id) {
            case .image(let n, let thumb):
                Text("image \(n)")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .lineLimit(1)
                    .padding(.trailing, 8)
                if let img = thumb {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            case .sticker(let n, let thumb):
                Text("sticker \(n)")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .lineLimit(1)
                    .padding(.trailing, 8)
                if let img = thumb {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            case .label(let n, let thumb):
                Text("label \(n)")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .lineLimit(1)
                    .padding(.trailing, 8)
                if let img = thumb {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
            case .text(let n, let content):
                Text("text \(n)")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .lineLimit(1)
                    .padding(.trailing, 8)
                Text("\"\(content)\"")
                    .font(.appBody)
                    .foregroundColor(.appDarkGray)
                    .lineLimit(1)
            case .unknown:
                Text("layer")
                    .font(.appBody)
                    .foregroundColor(.appBlack)
                    .lineLimit(1)
            }

            Spacer()

            // X 버튼
            Button {
                onDeleteLayer(id)
            } label: {
                Image("button_x")
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            .opacity(isBackground ? 0.3 : 1)
            .disabled(isBackground)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapLayer(id) }
        .opacity(isDragging ? 0.4 : 1)
    }

    private var backgroundRow: some View {
        HStack(spacing: 0) {
            Image("button_handle")
                .resizable()
                .frame(width: 16, height: 16)
                .opacity(0.3)

            Spacer().frame(width: 12)

            Text("cassette background")
                .font(.appBody)
                .foregroundColor(.appBlack)
                .padding(.trailing, 8)

            if let color = cassetteColors.first(where: { $0.name == cassetteColorName }) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.color)
                    .frame(width: 18, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Color.appGray.opacity(0.4), lineWidth: 0.5))
            }

            Spacer()

            Image("button_x")
                .resizable()
                .frame(width: 16, height: 16)
                .opacity(0.3)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapBackground() }
    }
}
