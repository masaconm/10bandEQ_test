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
/// EQPreset に filterType 情報を含める（拡張）
struct EQPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var eqValues: [Float]
    var filterTypeRawValues: [Int]?

    init(name: String, eqValues: [Float], filterTypes: [AVAudioUnitEQFilterType]? = nil) {
        self.id = UUID()
        self.name = name
        self.eqValues = eqValues
        self.filterTypeRawValues = filterTypes?.map { $0.rawValue }
    }

    var filterTypes: [AVAudioUnitEQFilterType]? {
        filterTypeRawValues?.compactMap { AVAudioUnitEQFilterType(rawValue: $0) }
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
    
    // MARK: - プリセット適用 + 各バンドのbypass制御
    func applyPresetWithBypass(_ preset: EQPreset) {
        eqValues = preset.eqValues

        for (index, value) in preset.eqValues.enumerated() {
            guard eqNode.bands.indices.contains(index) else { continue }
            let band = eqNode.bands[index]

            // 値を適用
            band.gain = value

            // フィルタータイプを適用（あれば）
            if let types = preset.filterTypes, types.indices.contains(index) {
                band.filterType = types[index]
            }

            // バイパス処理：0dBは完全スルー
            band.bypass = (value == 0)
        }
    }
    // MARK: - 「HI / MID / LOW ボタンを押したときに、それ以外の帯域を完全に切りたい（バイパス or カット）」
    //プリセットとは別に、それぞれ専用の切り替え関数を用意
    
    func applyBandOnly(_ band: String) {
        for (index, bandNode) in eqNode.bands.enumerated() {
            bandNode.filterType = .parametric

            // 初期化（バンドを "切る"）
            bandNode.gain = -40
            bandNode.bypass = false

            switch band {
            case "LOW" where index <= 2:
                bandNode.gain = 6
                bandNode.filterType = .lowShelf
            case "MID" where index >= 3 && index <= 6:
                bandNode.gain = 5
            case "HI" where index >= 7:
                bandNode.gain = 6
                bandNode.filterType = .highShelf
            default:
                break
            }

            // UI側にも反映
            if eqValues.indices.contains(index) {
                eqValues[index] = bandNode.gain
            }
        }
    }
    // MARK: - Default ボタンを追加（すべて0dBに戻し、バイパスOFF）
    func resetEQToDefault() {
        for (index, band) in eqNode.bands.enumerated() {
            band.gain = 0
            band.bypass = false
            band.filterType = .parametric

            if eqValues.indices.contains(index) {
                eqValues[index] = 0
            }
        }
    }

    
    // 組み込みプリセットおよびユーザープリセット（EQ設定）
    @Published var defaultPresets: [EQPreset] = [
        EQPreset(
            name: "Flat",
            eqValues: Array(repeating: 0, count: 10),
            filterTypes: Array(repeating: .parametric, count: 10)
        ),
        EQPreset(
            name: "LOW",
            eqValues: [6, 6, 5, 0, 0, 0, 0, 0, 0, 0],
            filterTypes: [.lowShelf, .lowShelf, .lowShelf, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric]
        ),
        EQPreset(
            name: "MID",
            eqValues: [0, 0, 0, 4, 5, 5, 4, 0, 0, 0],
            filterTypes: [.parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric]
        ),
        EQPreset(
            name: "HI",
            eqValues: [0, 0, 0, 0, 0, 0, 0, 5, 6, 6],
            filterTypes: [.parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .parametric, .highShelf, .highShelf, .highShelf]
        )
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
        MIDIMapping(parameterName: "EQ 8kHz", midiCC: 5),
        MIDIMapping(parameterName: "EQ 16kHz", midiCC: 6),
        MIDIMapping(parameterName: "GAIN", midiCC: 7)
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
        
        // 20250322 録音した音声をPlaylistへ追加
            NotificationCenter.default.addObserver(forName: .newRecordingFinished, object: nil, queue: .main) { [weak self] notification in
                guard let self = self else { return }
                if let url = notification.object as? URL {
                    print("📥 通知で受け取った録音ファイル: \(url.lastPathComponent)")
                    self.addAudioFileToPlaylist(url: url)
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
            eqNode.bands[index].bypass = false // スライダー操作時はバイパス解除！
        }
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
        let filterTypes = eqNode.bands.map { $0.filterType }
        let newPreset = EQPreset(name: name, eqValues: eqValues, filterTypes: filterTypes)
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
                    .stroke(Color(hex: "#00FFFF"), lineWidth: 1)
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
            .background(Color.black)
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

// MARK: -つまみ部分：固定サイズの正方形
struct SliderThumb: View {
    var thumbWidth: CGFloat = 40
    var thumbHeight: CGFloat = 20
    var thumbColor: Color = Color(hex: "#363739")

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(thumbColor)

            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(hex: "#1f2022"), lineWidth: 2)

            Rectangle()
                .fill(Color(hex: "#858585"))
                .frame(width: thumbWidth * 0.6, height: 2) // ✅ 横線！
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
}


// MARK: - カスタム Vertical Slider：つまみとトラックを個別に描画する縦型スライダー
struct CustomVerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var thumbWidth: CGFloat = 40          // ✅ 横幅
    var thumbHeight: CGFloat = 20         // ✅ 高さ
    var trackColor: Color = .gray
    var fillColor: Color = .blue
    var thumbColor: Color = .white

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let fillHeight = height * percentage
            let thumbY = height * (1 - percentage)

            ZStack {
                SliderTrack(
                    percentage: fillHeight,
                    width: width,
                    height: height,
                    trackColor: trackColor,
                    fillColor: fillColor
                )

                SliderThumb(
                    thumbWidth: thumbWidth,
                    thumbHeight: thumbHeight,
                    thumbColor: thumbColor
                )
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

//    // MARK: - Preview
    struct AudioEqualizerContentView_Previews: PreviewProvider {
        static var previews: some View {
            AudioEqualizerContentView()
                .environmentObject(AudioEngineViewModel())
                .previewInterfaceOrientation(.landscapeLeft)
                .frame(width: 1024, height: 768)
        }
    }

