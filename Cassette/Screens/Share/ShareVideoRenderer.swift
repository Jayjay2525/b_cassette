import AVFoundation
import UIKit
import Photos

enum ShareVideoRenderer {

    static func render(
        cassette: CassetteModel,
        backgroundColorHex: String,
        musicStartRatio: Double,
        onProgress: @escaping (Double) async -> Void
    ) async throws -> URL {

        // 출력 파일 경로
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(cassette.id.uuidString)_share.mp4")
        try? FileManager.default.removeItem(at: outputURL)

        // 720×1280 — Instagram Stories 충분한 품질, 1080p 대비 메모리 절반
        let videoSize = CGSize(width: 720, height: 1280)
        let duration: Double = 15.0  // 15초

        // AVAssetWriter 설정
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,  // 4 Mbps
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height),
            ]
        )

        writer.add(videoInput)

        // 오디오 트랙 추가
        var audioInput: AVAssetWriterInput? = nil
        var audioReader: AVAssetReader? = nil
        var audioTrackOutput: AVAssetReaderTrackOutput? = nil

        if let audioURL = resolveTrackURL(for: cassette) {
            let audioAsset = AVURLAsset(url: audioURL)
            if let audioTrack = try? await audioAsset.loadTracks(withMediaType: .audio).first {
                let audioOutputSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                ]
                let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioOutputSettings)

                // 시작 시간 설정
                let assetDuration = try await audioAsset.load(.duration)
                let totalSecs = CMTimeGetSeconds(assetDuration)
                let startSecs = totalSecs * musicStartRatio
                let startTime = CMTime(seconds: startSecs, preferredTimescale: 44100)
                let endTime = CMTime(seconds: min(startSecs + duration, totalSecs), preferredTimescale: 44100)

                let reader = try AVAssetReader(asset: audioAsset)
                reader.timeRange = CMTimeRange(start: startTime, end: endTime)
                reader.add(trackOutput)

                let audioSettings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 2,
                    AVEncoderBitRateKey: 128000,
                ]
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                input.expectsMediaDataInRealTime = false
                writer.add(input)

                audioInput = input
                audioReader = reader
                audioTrackOutput = trackOutput
            }
        }

        // 프레임 렌더링
        let bCuts = cassette.bCuts
        let bgColor = UIColor(hex: backgroundColorHex) ?? .black
        print("[ShareVideoRenderer] 사진 로딩 시작 (\(bCuts.count)장)")
        // 셀 픽셀 크기(~315×420)보다 크게 로드해야 업스케일 블러 방지
        let cellPixelW = 118.0 * videoSize.width / 270.0
        let cellPixelH = cellPixelW * 4.0 / 3.0
        let photos = await loadPhotos(bCuts: bCuts, targetSize: CGSize(width: cellPixelW * 1.5, height: cellPixelH * 1.5))
        print("[ShareVideoRenderer] 사진 로딩 완료")

        // 그리드를 한 번만 합성 (이후 프레임마다 crop만 수행)
        print("[ShareVideoRenderer] 그리드 합성 시작")
        let gridStrip = Self.makeGridStrip(photos: photos, videoSize: videoSize)
        print("[ShareVideoRenderer] 그리드 합성 완료")

        // 정적 오버레이 레이어도 미리 합성
        let staticOverlay = Self.makeStaticOverlay(cassette: cassette, videoSize: videoSize, bgColor: bgColor)
        print("[ShareVideoRenderer] 오버레이 합성 완료")

        guard writer.startWriting() else {
            print("[ShareVideoRenderer] writer.startWriting() 실패: \(writer.error?.localizedDescription ?? "unknown")")
            throw writer.error ?? NSError(domain: "ShareVideoRenderer", code: -1)
        }
        audioReader?.startReading()
        writer.startSession(atSourceTime: .zero)
        print("[ShareVideoRenderer] 비디오 쓰기 시작")

        let fps: Double = 24
        let totalFrames = Int(duration * fps)
        let frameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
        print("[ShareVideoRenderer] 총 \(totalFrames)프레임 렌더 예정")

        let maxScroll = max(0, (gridStrip?.size.height ?? videoSize.height) - videoSize.height)
        let gridStripBox = UncheckedSendableBox(gridStrip)
        let staticOverlayBox = UncheckedSendableBox(staticOverlay)
        let videoInputBox = UncheckedSendableBox(videoInput)
        let adaptorBox = UncheckedSendableBox(adaptor)
        let bgColorBox = UncheckedSendableBox(bgColor)

        // 비디오와 오디오를 동시에 write (pre-render 불필요 — 오디오 동시 공급으로 isReadyForMoreMediaData 정상 동작)
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()

            // 비디오: frame-by-frame 렌더 + write
            group.enter()
            DispatchQueue(label: "videoQueue").async {
                for frameIndex in 0..<totalFrames {
                    while !videoInputBox.value.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
                    let scrollY = CGFloat(frameIndex) / CGFloat(totalFrames) * maxScroll
                    let frameImage = Self.makeFrameImage(
                        size: videoSize,
                        bgColor: bgColorBox.value,
                        gridStrip: gridStripBox.value,
                        staticOverlay: staticOverlayBox.value,
                        scrollOffset: scrollY
                    )
                    if let buffer = Self.makeFrameBuffer(from: frameImage) {
                        adaptorBox.value.append(buffer, withPresentationTime: presentationTime)
                    }
                    if frameIndex % 30 == 0 {
                        print("[ShareVideoRenderer] video: \(frameIndex)/\(totalFrames)")
                    }
                }
                print("[ShareVideoRenderer] 비디오 완료")
                videoInputBox.value.markAsFinished()
                group.leave()
            }

            // 오디오 쓰기 (있으면)
            if let audioInput, let audioReader, let audioTrackOutput {
                let audioInputBox = UncheckedSendableBox(audioInput)
                let audioReaderBox = UncheckedSendableBox(audioReader)
                let audioTrackOutputBox = UncheckedSendableBox(audioTrackOutput)
                group.enter()
                DispatchQueue(label: "audioQueue").async {
                    while true {
                        while !audioInputBox.value.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.001)
                        }
                        if audioReaderBox.value.status == .reading,
                           let sampleBuffer = audioTrackOutputBox.value.copyNextSampleBuffer() {
                            audioInputBox.value.append(sampleBuffer)
                        } else {
                            print("[ShareVideoRenderer] 오디오 완료 (reader status: \(audioReaderBox.value.status.rawValue))")
                            audioInputBox.value.markAsFinished()
                            group.leave()
                            return
                        }
                    }
                }
            } else {
                print("[ShareVideoRenderer] 오디오 트랙 없음 — 스킵")
            }

            group.notify(queue: .global()) {
                continuation.resume()
            }
        }

        await onProgress(0.8)

        await onProgress(0.95)
        print("[ShareVideoRenderer] finishWriting 대기 중...")

        await writer.finishWriting()

        print("[ShareVideoRenderer] writer 상태: \(writer.status.rawValue), error: \(writer.error?.localizedDescription ?? "none")")
        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "ShareVideoRenderer", code: -1)
        }

        await onProgress(1.0)
        return outputURL
    }

    // MARK: - 그리드 strip 한 번 합성 (카드 레이아웃 기준으로 스케일)

    private static func makeGridStrip(photos: [UIImage?], videoSize: CGSize) -> UIImage? {
        guard !photos.isEmpty else { return nil }
        // 카드 기준: cellW=118, cellH=157(3:4), gap=6, padding=6 → 비디오 너비 360/카드 너비 270 배율 적용
        let scale = videoSize.width / 270
        let cols = 2
        let cellW = 118 * scale
        let cellH = cellW * 4 / 3   // 3:4 비율
        let gap = 6 * scale
        let padding = 6 * scale
        let rows = Int(ceil(Double(photos.count) / Double(cols))) + 1
        let stripH = padding + CGFloat(rows) * (cellH + gap)

        UIGraphicsBeginImageContextWithOptions(CGSize(width: videoSize.width, height: stripH), false, 1.0)
        defer { UIGraphicsEndImageContext() }

        // 2열을 videoSize.width 기준으로 중앙 정렬
        let totalGridW = CGFloat(cols) * cellW + CGFloat(cols - 1) * gap
        let leftMargin = (videoSize.width - totalGridW) / 2

        for row in 0..<rows {
            for col in 0..<cols {
                let idx = (row * cols + col) % photos.count
                let x = leftMargin + CGFloat(col) * (cellW + gap)
                let y = padding + CGFloat(row) * (cellH + gap)
                let cellRect = CGRect(x: x, y: y, width: cellW, height: cellH)
                if let img = photos[idx] {
                    img.draw(in: cellRect)
                } else {
                    UIColor.gray.withAlphaComponent(0.3).setFill()
                    UIRectFill(cellRect)
                }
            }
        }
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - 정적 오버레이 합성 (카드 레이아웃과 동일: Z3 검정 75% + Z4 카세트 이미지/텍스트)

    private static func makeStaticOverlay(cassette: CassetteModel, videoSize: CGSize, bgColor: UIColor) -> UIImage? {
        // 카드 기준 비율 그대로 유지 (가로/세로 각각 스케일)
        let scaleX = videoSize.width / 270
        let scaleY = videoSize.height / 433
        UIGraphicsBeginImageContextWithOptions(videoSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        guard UIGraphicsGetCurrentContext() != nil else { return nil }

        // Z3: 검정 75% rounded rect (카드 비율 204×195 그대로)
        let overlayW = 204 * scaleX
        let overlayH = 195 * scaleY
        let overlayRect = CGRect(
            x: (videoSize.width - overlayW) / 2,
            y: (videoSize.height - overlayH) / 2,
            width: overlayW, height: overlayH
        )
        UIColor.black.withAlphaComponent(0.75).setFill()
        UIBezierPath(roundedRect: overlayRect, cornerRadius: 16 * scaleX).fill()

        // Z4 레이아웃: "b_cassette" → 카세트 이미지 → 카세트 이름 → 날짜
        var curY = overlayRect.minY + 8 * scaleY

        let fontMicro = UIFont(name: "CutiveMono-Regular", size: 15 * scaleX) ?? UIFont.systemFont(ofSize: 15 * scaleX)
        let fontBody  = UIFont(name: "CutiveMono-Regular", size: 18 * scaleX) ?? UIFont.systemFont(ofSize: 18 * scaleX)

        // "b_cassette" 레이블
        let appStr = NSAttributedString(string: "b_cassette", attributes: [
            .font: fontMicro,
            .foregroundColor: UIColor.white.withAlphaComponent(0.6),
        ])
        let appSz = appStr.size()
        appStr.draw(at: CGPoint(x: (videoSize.width - appSz.width) / 2, y: curY))
        curY += appSz.height + 4 * scaleY

        // 카세트 디자인 이미지 (카드와 동일하게 130pt 기준 scaleX)
        let cassetteImage: UIImage?
        if let path = cassette.customImagePath {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(path)
            cassetteImage = UIImage(contentsOfFile: url.path)
        } else {
            cassetteImage = UIImage(named: cassette.design.imageName)
        }
        let imgW = 130 * scaleX
        let imgH: CGFloat
        if let img = cassetteImage {
            imgH = imgW * img.size.height / img.size.width
            img.draw(in: CGRect(x: (videoSize.width - imgW) / 2, y: curY, width: imgW, height: imgH))
        } else {
            imgH = 60 * scaleY
        }
        curY += imgH + 4 * scaleY

        // 카세트 이름
        let nameStr = NSAttributedString(string: cassette.name, attributes: [
            .font: fontBody,
            .foregroundColor: UIColor.white,
        ])
        let nameSz = nameStr.size()
        nameStr.draw(at: CGPoint(x: (videoSize.width - nameSz.width) / 2, y: curY))
        curY += nameSz.height + 4 * scaleY

        // 날짜
        if let range = cassette.photoDateRange {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy.MM.dd"
            let dateStr = NSAttributedString(
                string: "\(fmt.string(from: range.oldest)) — \(fmt.string(from: range.latest))",
                attributes: [
                    .font: fontMicro,
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                ]
            )
            let dateSz = dateStr.size()
            dateStr.draw(at: CGPoint(x: (videoSize.width - dateSz.width) / 2, y: curY))
        }

        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - 프레임 UIImage 렌더 (UIGraphicsImageRenderer 사용 — 좌표계 자동 처리, 캐시 최적화)

    private static func makeFrameImage(
        size: CGSize,
        bgColor: UIColor,
        gridStrip: UIImage?,
        staticOverlay: UIImage?,
        scrollOffset: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // @3x 방지 — 비디오 픽셀은 1:1이어야 함
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            // Z1: 배경색
            bgColor.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            // Z2: 그리드 strip을 scrollOffset만큼 위로 올려서 그리기
            if let strip = gridStrip {
                strip.draw(at: CGPoint(x: 0, y: -scrollOffset))
            }

            // Z3+Z4: 정적 오버레이
            staticOverlay?.draw(at: .zero)
        }
    }

    // UIImage → CVPixelBuffer 변환
    private static func makeFrameBuffer(from image: UIImage) -> CVPixelBuffer? {
        let size = image.size
        var buffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, Int(size.width), Int(size.height),
            kCVPixelFormatType_32ARGB, attrs, &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ), let cgImage = image.cgImage else { return nil }

        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }

    // MARK: - 헬퍼

    private static func loadPhotos(bCuts: [BCutPhoto], targetSize: CGSize) async -> [UIImage?] {
        var results: [UIImage?] = []
        for photo in bCuts {
            let img = await loadPhoto(photo, targetSize: targetSize)
            results.append(img)
        }
        return results.isEmpty ? [nil] : results
    }

    private static func loadPhoto(_ photo: BCutPhoto, targetSize: CGSize) async -> UIImage? {
        switch photo.imageSource {
        case .file(let url):
            return UIImage(contentsOfFile: url.path)
        case .bundleAsset(let name):
            return UIImage(named: name)
        case .asset(let id):
            return await withCheckedContinuation { continuation in
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                guard let asset = result.firstObject else {
                    continuation.resume(returning: nil)
                    return
                }
                let opts = PHImageRequestOptions()
                opts.deliveryMode = .highQualityFormat
                opts.isSynchronous = false
                PHImageManager.default().requestImage(
                    for: asset, targetSize: targetSize,
                    contentMode: .aspectFill, options: opts
                ) { img, _ in
                    continuation.resume(returning: img)
                }
            }
        }
    }

    private static func resolveTrackURL(for cassette: CassetteModel) -> URL? {
        let trackName = cassette.trackName
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cassettes/\(cassette.id.uuidString)/\(trackName)")
        if FileManager.default.fileExists(atPath: localURL.path) { return localURL }
        let parts = trackName.components(separatedBy: ".")
        guard parts.count == 2 else { return nil }
        return Bundle.main.url(forResource: parts[0], withExtension: parts[1])
    }
}

// MARK: - UIColor helpers

// MARK: - Sendable wrapper

private final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
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

    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}
