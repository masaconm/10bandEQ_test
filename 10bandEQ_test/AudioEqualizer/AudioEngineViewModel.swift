//
//  Untitled.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/04/15.
//
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - AudioEngineViewModel (修正版)
// AudioSessionManager, MIDIManager は別ファイルにある前提です。
class AudioEngineViewModel: ObservableObject {
    
    // MARK: - プロパティ定義
    @Published var currentLanguage: String = "English"
    @Published var isLoadingWaveform: Bool = false
    
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
    var audioEngineManager = AudioEngineManager()

    // プレイリスト関連
    @Published var playlistItems: [PlaylistItem] = []
    @Published var currentPlaylistItem: PlaylistItem? = nil
    
    
    

    
    func stopMonitoring() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
//        isMonitoringOnly = false
        print("🛑 Monitoring stopped")
    }

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
    //20250407 更新テスト
    // 複数バンド選択に対応した関数
    func applySelectedBands(low: Bool, mid: Bool, high: Bool) {
        for (index, bandNode) in eqNode.bands.enumerated() {
            bandNode.filterType = .parametric
            bandNode.gain = -40
            bandNode.bypass = false
            
            if low && index <= 2 {
                bandNode.gain = 6
                bandNode.filterType = .lowShelf
            } else if mid && (3...6).contains(index) {
                bandNode.gain = 5
            } else if high && index >= 7 {
                bandNode.gain = 6
                bandNode.filterType = .highShelf
            }
            
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
            name: "FLAT",
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
                pausedFrame = max(0, playerTime.sampleTime)
            }
            playerNode.stop()
            playbackTimer?.invalidate()
            playbackTimer = nil
        } else {
            guard let file = audioFile else { return }
            
            pausedFrame = max(0, pausedFrame)
            let totalFrames = file.length
            let remainingFrames = max(0, totalFrames - pausedFrame)
            let framesToPlay = AVAudioFrameCount(remainingFrames)
            
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
        
        let totalFrames = file.length
        pausedFrame = max(0, min(pausedFrame, totalFrames - 1))
        
        let remainingFrames = max(0, totalFrames - pausedFrame)
        let framesToPlay = AVAudioFrameCount(remainingFrames)
        
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
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
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
        print("🧩 プレイリスト追加リクエスト: \(url.lastPathComponent)")
        
        // ✅ 既にURLが登録済みならスキップ
        if playlistItems.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            print("⚠️ 既に追加済みのファイル: \(url.lastPathComponent)")
            return
        }
        
        guard let newItem = PlaylistItem(url: url) else {
            print("⚠️ PlaylistItemの生成に失敗")
            return
        }
        
        playlistItems.append(newItem)
        savePlaylistToDefaults()
        print("✅ プレイリストに追加: \(newItem.title)")
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



