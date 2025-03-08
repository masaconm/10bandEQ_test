//
//  AudioEqualizerViewController.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/02/24.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
// Waveform ライブラリは、SmoothWaveformView で独自実装するため不要

// MARK: - Clamp Function
/// 値を minValue と maxValue の範囲に収める（クランプする）関数
func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    return min(max(value, minValue), maxValue)
}

// MARK: - SampleBuffer
/// 波形表示用のサンプル配列を保持する構造体
struct SampleBuffer {
    var samples: [Float]
}

// MARK: - EQPreset
/// EQ プリセットのデータ構造。ユーザーが設定した EQ の各バンドの値を保持する。
/// Codable に準拠しているので、JSON での保存／読み込みが可能。
struct EQPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var eqValues: [Float]
    
    init(name: String, eqValues: [Float]) {
        self.id = UUID()
        self.name = name
        self.eqValues = eqValues
    }
}

// MARK: - PlaylistItem
/// プレイリストに追加される音声ファイルの情報を保持する構造体
/// URL、タイトル、再生時間（秒）を含み、Codable に準拠しているので永続保存が可能。
struct PlaylistItem: Identifiable, Codable {
    var id = UUID()
    let url: URL
    let title: String
    let duration: Double  // seconds
    
    /// 指定した URL から AVAudioFile を読み込み、再生時間などを計算して初期化する。
    init?(url: URL) {
        self.url = url
        self.title = url.lastPathComponent
        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            self.duration = Double(file.length) / sampleRate
        } catch {
            print("Failed to load file for duration: \(error)")
            return nil
        }
    }
}

// MARK: - DocumentPicker
/// UIDocumentPickerViewController を SwiftUI で利用するための UIViewControllerRepresentable
/// ユーザーが音声ファイルを選択するために使用する。
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // UTType.audio により音声ファイルを選択対象に
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = true
        controller.modalPresentationStyle = .formSheet
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    // Coordinator は UIDocumentPickerDelegate を実装し、選択結果を onPick クロージャに渡す
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// MARK: - グローバル関数：ファイルを Documents ディレクトリにコピーする
/// 選択されたファイルを永続保存可能な場所（Documents ディレクトリ）にコピーする関数。
func copyFileToDocuments(url: URL) -> URL? {
    let fileManager = FileManager.default
    // Documents ディレクトリの取得
    guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }
    let destinationURL = documentsDir.appendingPathComponent(url.lastPathComponent)
    do {
        // 同名のファイルが存在すれば削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        // コピー実行
        try fileManager.copyItem(at: url, to: destinationURL)
        return destinationURL
    } catch {
        print("Failed to copy file: \(error)")
        return nil
    }
}

//
// MARK: - AudioEngineViewModel.swift
//


// MARK: - AudioEngineViewModel (修正版)
// AudioSessionManager, MIDIManager は別ファイルにある前提です。
class AudioEngineViewModel: ObservableObject {
    
    // MARK: - プロパティ定義
    @Published var currentLanguage: String = "English"
    
    // 10バンド EQ の周波数設定
    let eqBandsFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var eqValues: [Float] = Array(repeating: 0, count: 10)
    
    // レベル（dB）、波形表示用のサンプルバッファ、再生進捗の管理
    @Published var level: Float = -50
    @Published var sampleBuffer: SampleBuffer? = nil
    @Published var playbackProgress: Double = 0.0
    @Published var isSeeking: Bool = false
    
    // マスターゲイン（出力音量）
    @Published var gain: Float = 1.0 {
        didSet { audioEngine.mainMixerNode.outputVolume = gain }
    }
    
    // AVAudioEngine 関連
    var audioEngine = AVAudioEngine()
    var playerNode = AVAudioPlayerNode()
    var eqNode: AVAudioUnitEQ!
    var audioFile: AVAudioFile? = nil
    var pausedFrame: AVAudioFramePosition = 0
    var playbackTimer: Timer?
    
    // プレイリスト関連
    @Published var playlistItems: [PlaylistItem] = []
    @Published var currentPlaylistItem: PlaylistItem? = nil
    
    // 組み込みプリセットおよびユーザープリセット（EQ設定）
    @Published var defaultPresets: [EQPreset] = [
        EQPreset(name: "Flat", eqValues: Array(repeating: 0, count: 10)),
        EQPreset(name: "Rock", eqValues: [5, 3, 0, -2, -2, 0, 3, 5, 7, 10])
    ]
    @Published var userPresets: [EQPreset] = []
    
    // MIDIManager のインスタンス（MIDI コントローラー対応用）
    var midiManager: MIDIManager? = nil
    
    // MIDIマッピングの配列（例として EQ の各バンド＋ GAIN を管理）
    @Published var midiMappings: [MIDIMapping] = [
        MIDIMapping(parameterName: "EQ 32Hz", midiCC: 16),
        MIDIMapping(parameterName: "EQ 64Hz", midiCC: 17),
        MIDIMapping(parameterName: "EQ 125Hz", midiCC: 18),
        MIDIMapping(parameterName: "EQ 250Hz", midiCC: 19),
        MIDIMapping(parameterName: "EQ 500Hz", midiCC: 20),
        MIDIMapping(parameterName: "EQ 1kHz", midiCC: 21),
        MIDIMapping(parameterName: "EQ 2kHz", midiCC: 22),
        MIDIMapping(parameterName: "EQ 4kHz", midiCC: 23),
        MIDIMapping(parameterName: "EQ 8kHz", midiCC: 24),
        MIDIMapping(parameterName: "EQ 16kHz", midiCC: 25),
        MIDIMapping(parameterName: "GAIN", midiCC: 26)
    ]
    
    // MARK: - 初期化処理
    init() {
        loadUserPresetsFromDefaults()
        loadPlaylistFromDefaults()
        
        // オーディオセッションは別ファイルの AudioSessionManager を利用
        AudioSessionManager.configureSession()
        
        // MIDIManager の初期化
        midiManager = MIDIManager()
        midiManager?.midiMessageHandler = { [weak self] midiMessage in
            guard let self = self else { return }
            // MIDI メッセージが3バイト以上かつコントロールチェンジの場合
            if midiMessage.count >= 3 {
                let status = midiMessage[0]
                let control = midiMessage[1]
                let value = midiMessage[2]
                if status & 0xF0 == 0xB0 {
                    // カスタムマッピングのリストから、受信した CC 番号と一致するパラメーターを探す
                    if let mapping = self.midiMappings.first(where: { $0.midiCC == Int(control) }) {
                        // ここでは例として、EQ バンドの場合に updateEQ を呼び出す
                        // ※ 例えば "GAIN" は別処理にするなど、条件分岐が必要です
                        if mapping.parameterName.hasPrefix("EQ") {
                            // マッピングの順番に対応するインデックスを決定（例："EQ 32Hz"なら index 0）
                            if let index = self.midiMappings.firstIndex(where: { $0.id == mapping.id }) {
                                let newGain = Float(Double(value) / 127.0 * 80.0 - 40.0)
                                DispatchQueue.main.async {
                                    self.updateEQ(at: index, value: newGain)
                                }
                            }
                        }
                        // GAIN などの場合は別途処理
                        if mapping.parameterName == "GAIN" {
                            let newGain = Float(Double(value) / 127.0 * 2.0)
                            DispatchQueue.main.async {
                                self.gain = newGain
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Audio Engine の初期化処理
    func startAudioEngine() {
        eqNode = AVAudioUnitEQ(numberOfBands: eqBandsFrequencies.count)
        for (index, band) in eqNode.bands.enumerated() {
            band.filterType = (index == 0) ? .lowShelf : ((index == eqBandsFrequencies.count - 1) ? .highShelf : .parametric)
            band.frequency = eqBandsFrequencies[index]
            band.gain = eqValues[index]
            band.bypass = false
        }
        audioEngine.attach(playerNode)
        audioEngine.attach(eqNode)
        
        guard let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) else {
            print("Failed to create stereo format")
            return
        }
        
        audioEngine.connect(playerNode, to: eqNode, format: stereoFormat)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: stereoFormat)
        
        let mainMixer = audioEngine.mainMixerNode
        mainMixer.installTap(onBus: 0, bufferSize: 1024, format: mainMixer.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            DispatchQueue.main.async {
                self?.updateLevel(from: buffer)
            }
        }
        mainMixer.outputVolume = gain
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }
    
    // MARK: - EQ 更新処理
    func updateEQ(at index: Int, value: Float) {
        eqValues[index] = value
        if eqNode.bands.indices.contains(index) {
            eqNode.bands[index].gain = value
        }
        print("EQ band \(index) set to \(value)")
    }
    
    // MARK: - レベル更新処理
    func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sum / Float(frameLength))
        self.level = 20 * log10(rms + 1e-12)
    }
    
    // MARK: - 再生／停止およびシーク処理
    func togglePlayback() {
        if playerNode.isPlaying {
            if let nodeTime = playerNode.lastRenderTime,
               let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
                pausedFrame = max(playerTime.sampleTime, 0)
            }
            playerNode.stop()
            playbackTimer?.invalidate()
            playbackTimer = nil
        } else {
            guard let file = audioFile else { return }
            pausedFrame = max(pausedFrame, 0)
            let totalFrames = file.length
            let framesToPlay = AVAudioFrameCount(totalFrames - pausedFrame)
            if framesToPlay > 0 {
                playerNode.scheduleSegment(file,
                                           startingFrame: pausedFrame,
                                           frameCount: framesToPlay,
                                           at: nil,
                                           completionHandler: nil)
            }
            playerNode.play()
            startPlaybackTimer()
        }
    }
    
    func seekToCurrentPausedFrameAndResume() {
        guard let file = audioFile else { return }
        playerNode.stop()
        pausedFrame = max(pausedFrame, 0)
        let totalFrames = file.length
        let framesToPlay = AVAudioFrameCount(totalFrames - pausedFrame)
        if framesToPlay > 0 {
            playerNode.scheduleSegment(file,
                                       startingFrame: pausedFrame,
                                       frameCount: framesToPlay,
                                       at: nil,
                                       completionHandler: nil)
        }
        playerNode.play()
    }
    
    // MARK: - 再生中の進捗更新処理
    func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let file = self.audioFile,
                  let nodeTime = self.playerNode.lastRenderTime,
                  let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
            let overallSamplePosition = Double(self.pausedFrame) + Double(playerTime.sampleTime)
            let duration = Double(file.length)
            self.playbackProgress = clamp(overallSamplePosition / duration, 0.0, 1.0)
        }
    }
    
    // MARK: - プレイリスト管理・EQプリセット管理
    func savePlaylistToDefaults() {
        do {
            let data = try JSONEncoder().encode(playlistItems)
            UserDefaults.standard.set(data, forKey: "playlistItems")
        } catch {
            print("Failed to encode playlist items: \(error)")
        }
    }
    
    func loadPlaylistFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: "playlistItems") {
            do {
                let items = try JSONDecoder().decode([PlaylistItem].self, from: data)
                self.playlistItems = items
            } catch {
                print("Failed to decode playlist items: \(error)")
            }
        }
    }
    
    func loadPlaylistItem(_ item: PlaylistItem) {
        currentPlaylistItem = item
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let file = try AVAudioFile(forReading: item.url)
                DispatchQueue.main.async {
                    self.audioFile = file
                    self.pausedFrame = 0
                    self.playerNode.stop()
                    self.playerNode.reset()
                }
                let frameCount = AVAudioFrameCount(file.length)
                guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
                    print("Failed to create PCM buffer")
                    return
                }
                try file.read(into: pcmBuffer)
                if let channelData = pcmBuffer.floatChannelData?[0] {
                    let totalSamples = Int(pcmBuffer.frameLength)
                    let maxSamples = 5000
                    let downsampleFactor = max(totalSamples / maxSamples, 1)
                    let samples = (0..<totalSamples).compactMap { index -> Float? in
                        return (index % downsampleFactor == 0) ? channelData[index] : nil
                    }
                    DispatchQueue.main.async {
                        self.sampleBuffer = SampleBuffer(samples: samples)
                        print("Loaded \(samples.count) samples (downsampled from \(totalSamples))")
                    }
                }
                DispatchQueue.main.async {
                    self.playerNode.stop()
                    self.playerNode.reset()
                    let totalFrames = file.length
                    let framesToPlay = AVAudioFrameCount(totalFrames)
                    if framesToPlay > 0 {
                        self.playerNode.scheduleSegment(file,
                                                        startingFrame: 0,
                                                        frameCount: framesToPlay,
                                                        at: nil,
                                                        completionHandler: nil)
                    }
                    self.playerNode.play()
                    self.startPlaybackTimer()
                }
            } catch {
                DispatchQueue.main.async {
                    print("Failed to load playlist item: \(error)")
                }
            }
        }
    }
    
    func addAudioFileToPlaylist(url: URL) {
        if let permanentURL = copyFileToDocuments(url: url),
           let newItem = PlaylistItem(url: permanentURL) {
            if !playlistItems.contains(where: { $0.url == newItem.url }) {
                playlistItems.append(newItem)
                savePlaylistToDefaults()
            }
            if audioFile == nil {
                loadPlaylistItem(newItem)
            }
        } else {
            print("Failed to copy and add the audio file to playlist")
        }
    }
    
    // MARK: - EQプリセット管理
    func savePreset(with name: String) {
        let newPreset = EQPreset(name: name, eqValues: eqValues)
        userPresets.append(newPreset)
        saveUserPresetsToDefaults()
    }
    
    func applyPreset(_ preset: EQPreset) {
        eqValues = preset.eqValues
        for (index, value) in preset.eqValues.enumerated() {
            updateEQ(at: index, value: value)
        }
    }
    
    func loadUserPresetsFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: "userPresets") {
            do {
                let presets = try JSONDecoder().decode([EQPreset].self, from: data)
                self.userPresets = presets
            } catch {
                print("Failed to decode user presets: \(error)")
            }
        }
    }
    
    func saveUserPresetsToDefaults() {
        do {
            let data = try JSONEncoder().encode(userPresets)
            UserDefaults.standard.set(data, forKey: "userPresets")
        } catch {
            print("Failed to encode user presets: \(error)")
        }
    }
    
    func removePreset(named name: String) {
        if let index = userPresets.firstIndex(where: { $0.name == name }) {
            userPresets.remove(at: index)
            saveUserPresetsToDefaults()
        }
    }
} // <-- AudioEngineViewModel 終了

// MARK: - 以降、その他の View 定義（SmoothWaveformView, LevelMeterViewSwiftUI, CustomVerticalSlider, HeaderView, EQContainerView, AudioEqualizerContentView, etc.）…


// 以降、SmoothWaveformView、LevelMeterViewSwiftUI、CustomVerticalSlider、HeaderView、EQContainerView、AudioEqualizerContentView など他の View 定義は続きます…


// MARK: - SmoothWaveformView (新UI)
// 【仕様】
// - 音声読み込み時は波形は画面左寄せで表示
// - zoomScale に応じて波形の横幅が拡大
// - playbackProgress (0...1) に基づき、波形全体での x 座標を計算し、
//   zoomScale > 1 の場合はオフセットを計算して、常に再生位置が画面中央に表示される
struct SmoothWaveformView: View {
    let sampleBuffer: SampleBuffer   // -1...1 に正規化済みサンプル
    let playbackProgress: Double     // 0...1 (再生進行度)
    let zoomScale: CGFloat           // 拡大率（外部から渡す）
    
    var body: some View {
        GeometryReader { geo in
            // コンテナサイズ
            let containerWidth = geo.size.width
            let containerHeight = geo.size.height
            
            // 波形全体の横幅 = コンテナ幅 × zoomScale
            let waveformWidth = containerWidth * zoomScale
            
            // 再生位置の x 座標 = playbackProgress × waveformWidth
            let playbackX = CGFloat(playbackProgress) * waveformWidth
            
            // 拡大時は、再生位置が常に画面中央に来るように offset を計算
            let offsetX: CGFloat = waveformWidth > containerWidth ? (containerWidth / 2 - playbackX) : 0
            
            // サンプル配列から各点の座標を生成
            let samples = sampleBuffer.samples.map { CGFloat($0) }
            let sampleCount = max(samples.count, 1)
            let step = waveformWidth / CGFloat(sampleCount - 1)
            let points: [CGPoint] = samples.enumerated().map { (index, sample) in
                let x = CGFloat(index) * step
                // サンプル値により上下の位置を決定（中央を 0 とする）
                let y = containerHeight / 2 - sample * (containerHeight / 2)
                return CGPoint(x: x, y: y)
            }
            
            ZStack(alignment: .leading) {
                // 波形を滑らかな曲線（補間 Path）として描画
                Path.smoothPath(with: points)
                    .stroke(Color.blue, lineWidth: 1)
                    .frame(width: waveformWidth, height: containerHeight)
                    .offset(x: offsetX)
            }
        }
    }
}

extension Path {
    /// 点群から滑らかな曲線の Path を生成する拡張関数
    static func smoothPath(with points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let midPoint = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
            path.addQuadCurve(to: midPoint, control: prev)
            if i == points.count - 1 {
                path.addQuadCurve(to: curr, control: curr)
            }
        }
        return path
    }
}

// MARK: - LevelMeterViewSwiftUI (新デザイン)
// 【仕様】
// 下から上にしきい値ごとに色を積み上げる表示
struct LevelMeterViewSwiftUI: View {
    var level: Float  // 現在の dB 値
    // しきい値とそれに対応する色（上に行くほど dB 値が大きい＝音が大きい）
    let thresholds: [(lkfs: Float, color: Color)] = [
        (0, .red),
        (-3, .red),
        (-6, .red),
        (-9, .orange),
        (-18, .orange),
        (-23, .yellow),
        (-27, .yellow),
        (-36, .green),
        (-45, .green),
        (-54, .green),
        (-64, .green)
    ]
    var body: some View {
        GeometryReader { geo in
            let maxHeight = geo.size.height
            let sectionHeight = maxHeight / CGFloat(thresholds.count)
            VStack(spacing: 0) {
                // thresholds を下から上に積み上げる
                ForEach(thresholds, id: \.lkfs) { threshold in
                    Rectangle()
                        .fill(level > threshold.lkfs ? threshold.color : Color.clear)
                        .frame(height: sectionHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .border(Color.white)
        }
    }
}

// MARK: - Custom Slider Components
/// スライダートラック：背景と充填部分を表示
//struct SliderTrack: View {
//    var percentage: CGFloat       // 充填部分の高さ（スライダーの値に基づく）
//    var width: CGFloat            // トラックの横幅
//    var trackColor: Color = .gray
//    var fillColor: Color = .blue
//    var body: some View {
//        ZStack(alignment: .bottom) {
//            Rectangle()
//                .fill(trackColor)
//                .frame(width: width)
//            Rectangle()
//                .fill(fillColor)
//                .frame(width: width, height: percentage)
//        }
//    }
//}

/// つまみ部分：固定サイズの正方形
struct SliderThumb: View {
    var thumbSize: CGFloat = 30
    var thumbColor: Color = .white
    var body: some View {
        // 正方形のつまみを表示
        Rectangle()
            .fill(thumbColor)
            .frame(width: thumbSize, height: thumbSize)
            .shadow(radius: 2)
    }
}

/// カスタム Vertical Slider：つまみとトラックを個別に描画する縦型スライダー
struct CustomVerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var thumbSize: CGFloat = 30
    var trackColor: Color = .gray
    var fillColor: Color = .blue
    var thumbColor: Color = .white
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            // 現在の値を 0～1 の割合に変換
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let fillHeight = height * percentage
            let thumbY = height * (1 - percentage)
            ZStack {
                SliderTrack(percentage: fillHeight, width: width, trackColor: trackColor, fillColor: fillColor)
                SliderThumb(thumbSize: thumbSize, thumbColor: thumbColor)
                    .position(x: width / 2, y: thumbY)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let clampedY = min(max(gesture.location.y, 0), height)
                                let newPercentage = 1 - (clampedY / height)
                                let newValue = range.lowerBound + Float(newPercentage) * (range.upperBound - range.lowerBound)
                                self.value = newValue
                            }
                    )
            }
        }
    }
}



// MARK: - EQContainerView
/// EQContainerView：EQスライダー群、GAINスライダー、レベルメーターを横並びで表示する
struct EQContainerView: View {
    let eqBands: [Float]
    @Binding var eqValues: [Float]
    var onSliderChanged: (Int, Float) -> Void
    var level: Float
    @Binding var gain: Float
    
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let containerHeight = geo.size.height
            // スライダー部分の高さ（EQやGAINはこの高さで表示）
            let sliderHeight = containerHeight * 0.66
            // ラベル部分の高さ（各スライダーの下部に表示される）
            let labelHeight = containerHeight * 0.34
            
            let eqAreaWidth = totalWidth * 0.6
            let gainSliderWidth = totalWidth * 0.1
            let meterWidth = (totalWidth - eqAreaWidth - gainSliderWidth) / 3
            
            HStack(spacing: 10) {
                // EQスライダー群：各バンドのスライダーと、その下に周波数と dB のラベル
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(eqBands.indices, id: \.self) { index in
                        VStack(spacing: 2) {
                            CustomVerticalSlider(
                                value: Binding(
                                    get: { eqValues[index] },
                                    set: { newValue in onSliderChanged(index, newValue) }
                                ),
                                range: -40...40,
                                thumbSize: 30,
                                trackColor: .gray,
                                fillColor: .blue,
                                thumbColor: .white
                            )
                            .frame(width: 30, height: sliderHeight)
                            
                            Text(eqBands[index] >= 1000 ?
                                 "\(eqBands[index]/1000, specifier: "%.1f") kHz" :
                                 "\(Int(eqBands[index])) Hz")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(height: labelHeight / 6)
                            
                            Text("\(eqValues[index], specifier: "%.1f") dB")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .frame(height: labelHeight / 4)
                        }
                        .frame(height: containerHeight)
                    }
                }
                .frame(width: eqAreaWidth)
                
                // GAINスライダー：上部はスライダー、下部にラベルと数値
                VStack(spacing: 2) {
                    CustomVerticalSlider(
                        value: $gain,
                        range: 0...2,
                        thumbSize: 30,
                        trackColor: .gray,
                        fillColor: .blue,
                        thumbColor: .white
                    )
                    .frame(width: 30, height: sliderHeight)
                    
                    Text("Gain")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 6)
                    Text("\(gain, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 4)
                }
                .frame(width: gainSliderWidth)
                
                // レベルメーター：バー部分と下部にラベルを配置
                VStack(spacing: 2) {
                    LevelMeterViewSwiftUI(level: level)
                        .frame(height: sliderHeight)
                    Text("Current Loudness")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 6)
                    Text(String(format: "%.2f dB", level))
                        .font(.caption2)
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 4)
                }
                .frame(width: meterWidth)
            }
            .padding(.horizontal, 10)
        }
        .background(Color.black.opacity(0.2))
    }
}


// MARK: - PresetSaveView
/// ユーザーが EQ プリセットを保存するための画面
struct PresetSaveView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    @State private var presetName: String = ""
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Preset Name")) {
                    TextField("Enter name", text: $presetName)
                }
                Button("Save") {
                    if !presetName.isEmpty {
                        viewModel.savePreset(with: presetName)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Save Preset")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - PresetLoadView
/// ユーザーが保存した EQ プリセットを読み込むための画面
struct PresetLoadView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Default Presets")) {
                    ForEach(viewModel.defaultPresets) { preset in
                        Button(action: {
                            viewModel.applyPreset(preset)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(preset.name)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                Section(header: Text("User Presets")) {
                    ForEach(viewModel.userPresets) { preset in
                        HStack {
                            // 左側：タップでプリセット適用
                            Button(action: {
                                viewModel.applyPreset(preset)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 右側：削除ボタン
                            Button(action: {
                                viewModel.removePreset(named: preset.name)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 44, height: 44)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Load Preset")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - PlaylistView
/// プレイリスト画面。各音声ファイル項目を表示し、タップで再生切り替え、ゴミ箱ボタンで削除できる
struct PlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.playlistItems) { item in
                    HStack {
                        // 左側：タップで音声を選択してシートを閉じる
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.headline)
                            Text(String(format: "Duration: %.2f sec", item.duration))
                                .font(.subheadline)
                        }
                        .onTapGesture {
                            viewModel.loadPlaylistItem(item)
                            presentationMode.wrappedValue.dismiss()
                        }
                        Spacer()
                        // 右側：削除ボタン。タップしてもシートは閉じない
                        Button(action: {
                            if let index = viewModel.playlistItems.firstIndex(where: { $0.id == item.id }) {
                                viewModel.playlistItems.remove(at: index)
                                viewModel.savePlaylistToDefaults()
                                // 現在再生中の項目が削除された場合、クリアする
                                if viewModel.currentPlaylistItem?.id == item.id {
                                    viewModel.currentPlaylistItem = nil
                                }
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Playlist")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Preview
struct AudioEqualizerContentView_Previews: PreviewProvider {
    static var previews: some View {
        AudioEqualizerContentView()
            .environmentObject(AudioEngineViewModel())
            .previewInterfaceOrientation(.landscapeLeft)
            .frame(width: 1024, height: 768)
    }
}

