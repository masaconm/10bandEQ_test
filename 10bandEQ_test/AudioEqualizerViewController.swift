import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Waveform

// MARK: - Clamp Function
func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    return min(max(value, minValue), maxValue)
}

// MARK: - EQPreset
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
struct PlaylistItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let duration: Double  // 秒
    
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
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
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
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// MARK: - AudioEngineViewModel
class AudioEngineViewModel: ObservableObject {
    @Published var currentLanguage: String = "English"
    
    // 10バンド EQ の周波数（Hz）
    let eqBandsFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    @Published var eqValues: [Float] = Array(repeating: 0, count: 10)
    @Published var level: Float = -50
    
    // Waveform 表示用の SampleBuffer
    @Published var sampleBuffer: SampleBuffer? = nil
    // Waveform 上の再生進行度（0～1）
    @Published var playbackProgress: Double = 0.0
    // ユーザーがシーク中はタイマー更新を抑制するためのフラグ
    @Published var isSeeking: Bool = false
    
    @Published var gain: Float = 1.0 {
        didSet { audioEngine.mainMixerNode.outputVolume = gain }
    }
    
    // オーディオエンジン関連
    var audioEngine = AVAudioEngine()
    var playerNode = AVAudioPlayerNode()
    var eqNode: AVAudioUnitEQ!
    var audioFile: AVAudioFile? = nil
    var pausedFrame: AVAudioFramePosition = 0
    var playbackTimer: Timer?
    
    // プレイリスト：読み込んだオーディオファイルの情報を PlaylistItem として保持
    @Published var playlistItems: [PlaylistItem] = []
    @Published var currentPlaylistItem: PlaylistItem? = nil
    
    // 組み込みプリセットとユーザー保存プリセット
    @Published var defaultPresets: [EQPreset] = [
        EQPreset(name: "Flat", eqValues: Array(repeating: 0, count: 10)),
        EQPreset(name: "Rock", eqValues: [5, 3, 0, -2, -2, 0, 3, 5, 7, 10])
    ]
    @Published var userPresets: [EQPreset] = []
    
    init() {
        loadUserPresetsFromDefaults()
    }
    
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
        audioEngine.connect(playerNode, to: eqNode, format: nil)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: nil)
        
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
    
    func updateEQ(at index: Int, value: Float) {
        eqValues[index] = value
        if eqNode.bands.indices.contains(index) {
            eqNode.bands[index].gain = value
        }
        print("EQ band \(index) set to \(value)")
    }
    
    func updateLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        let sum = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sum / Float(frameLength))
        let levelValue = 20 * log10(rms + 1e-12)
        self.level = levelValue
    }
    
    func togglePlayback() {
        if playerNode.isPlaying {
            if let nodeTime = playerNode.lastRenderTime,
               let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
                pausedFrame = playerTime.sampleTime
            }
            playerNode.stop()
            playbackTimer?.invalidate()
            playbackTimer = nil
        } else {
            guard let file = audioFile else { return }
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
    
    func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.isSeeking { return }
            guard let file = self.audioFile,
                  let nodeTime = self.playerNode.lastRenderTime,
                  let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
            let overallSamplePosition = Double(self.pausedFrame) + Double(playerTime.sampleTime)
            let duration = Double(file.length)
            self.playbackProgress = clamp(overallSamplePosition / duration, 0.0, 1.0)
        }
    }
    
    func loadPlaylistItem(_ item: PlaylistItem) {
        currentPlaylistItem = item
        do {
            let file = try AVAudioFile(forReading: item.url)
            self.audioFile = file
            pausedFrame = 0
            let channelData = file.floatChannelData()![0]

            let sampleCount = Int(file.length)
            let samples: [Float] = (0..<sampleCount).map { channelData[$0] }
            self.sampleBuffer = SampleBuffer(samples: samples)
            playerNode.stop()
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
        } catch {
            print("Failed to load playlist item: \(error)")
        }
    }
    
    func addAudioFileToPlaylist(url: URL) {
        if let newItem = PlaylistItem(url: url) {
            if !playlistItems.contains(where: { $0.url == newItem.url }) {
                playlistItems.append(newItem)
            }
            if audioFile == nil {
                loadPlaylistItem(newItem)
            }
        }
    }
    
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
}

// MARK: - PresetSaveView
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
struct PresetLoadView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Default Presets")) {
                    ForEach(viewModel.defaultPresets) { preset in
                        Button(preset.name) {
                            viewModel.applyPreset(preset)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                Section(header: Text("User Presets")) {
                    ForEach(viewModel.userPresets) { preset in
                        HStack {
                            Button(preset.name) {
                                viewModel.applyPreset(preset)
                                presentationMode.wrappedValue.dismiss()
                            }
                            Spacer()
                            Button(action: {
                                viewModel.removePreset(named: preset.name)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
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
struct PlaylistView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    
    var body: some View {
        NavigationView {
            List(viewModel.playlistItems) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(String(format: "Duration: %.2f sec", item.duration))
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.loadPlaylistItem(item)
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .navigationTitle("Playlist")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - HeaderView
struct HeaderView: View {
    @Binding var currentLanguage: String
    var body: some View {
        GeometryReader { geo in
            HStack {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding(.leading, 10)
                Spacer()
                Menu {
                    Button("English") { currentLanguage = "English" }
                    Button("日本語") { currentLanguage = "日本語" }
                } label: {
                    Text(currentLanguage)
                        .frame(width: 120, height: 30)
                        .background(Color.white)
                        .cornerRadius(5)
                }
                Spacer()
                if geo.size.width > geo.size.height {
                    Button("Presets") { }
                        .frame(width: 120, height: 30)
                        .background(Color.white)
                        .cornerRadius(5)
                        .padding(.trailing, 10)
                }
            }
        }
        .frame(height: 60)
        .background(Color.gray)
    }
}

// MARK: - EQContainerView
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
            let sliderHeight = containerHeight * 0.66
            let labelHeight = containerHeight * 0.34
            
            let eqAreaWidth = totalWidth * 0.6
            let gainSliderWidth = totalWidth * 0.1
            let meterWidth = (totalWidth - eqAreaWidth - gainSliderWidth) / 3
            
            HStack(spacing: 10) {
                // EQスライダー群
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(eqBands.indices, id: \.self) { index in
                        VStack(spacing: 2) {
                            Slider(value: Binding(
                                get: { eqValues[index] },
                                set: { newValue in
                                    onSliderChanged(index, newValue)
                                }
                            ), in: -40...40)
                            .rotationEffect(.degrees(-90))
                            .frame(height: sliderHeight)
                            
                            Text(eqBands[index] >= 1000 ?
                                 "\(eqBands[index]/1000, specifier: "%.1f") kHz" :
                                 "\(Int(eqBands[index])) Hz")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(height: labelHeight / 2)
                            
                            Text("\(eqValues[index], specifier: "%.1f") dB")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .frame(height: labelHeight / 2)
                        }
                        .frame(height: containerHeight)
                    }
                }
                .frame(width: eqAreaWidth)
                
                // ゲインスライダー
                VStack(spacing: 2) {
                    Slider(value: $gain, in: 0...2)
                        .rotationEffect(.degrees(-90))
                        .frame(height: sliderHeight)
                    Text("Gain")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 2)
                    Text("\(gain, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 2)
                }
                .frame(width: gainSliderWidth)
                
                // レベルメーター
                LevelMeterViewSwiftUI(level: level)
                    .frame(width: meterWidth)
            }
            .padding(.horizontal, 10)
        }
        .background(Color.black.opacity(0.2))
    }
}

// MARK: - LevelMeterViewSwiftUI
struct LevelMeterViewSwiftUI: View {
    var level: Float
    var body: some View {
        GeometryReader { geo in
            let normalized = max(min((level + 100) / 100, 1), 0)
            let meterHeight = geo.size.height * CGFloat(normalized)
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(Color.gray)
                Rectangle()
                    .fill(level > -6 ? Color.red :
                          level > -18 ? Color.orange :
                          level > -27 ? Color.yellow : Color.green)
                    .frame(height: meterHeight)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Loudness")
                        .font(.caption2)
                        .foregroundColor(.white)
                    Text(String(format: "%.2f dB", level))
                        .font(.caption2)
                        .foregroundColor(.white)
                }
                .padding(4)
            }
            .border(Color.white)
        }
    }
}

// MARK: - AudioEqualizerContentView
struct AudioEqualizerContentView: View {
    @StateObject var viewModel = AudioEngineViewModel()
    @State private var zoomScale: CGFloat = 1.0
    @State private var showingSavePreset = false
    @State private var showingLoadPreset = false
    @State private var showingPlaylist = false
    @State private var showingPicker = false  // オーディオファイル選択用
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderView(currentLanguage: $viewModel.currentLanguage)
                    .frame(height: 60)
                
                if let current = viewModel.currentPlaylistItem {
                    VStack {
                        Text(current.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(String(format: "Duration: %.2f sec", current.duration))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 5)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        if let sampleBuffer = viewModel.sampleBuffer {
                            Waveform(samples: sampleBuffer)
                                .foregroundColor(.blue)
                                .scaleEffect(x: zoomScale, y: 1, anchor: .leading)
                        } else {
                            Text("Audio file not loaded")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.gray)
                        }
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2)
                            .position(x: CGFloat(viewModel.playbackProgress) * geo.size.width,
                                      y: geo.size.height / 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                viewModel.isSeeking = true
                                let newProgress = clamp(Double(value.location.x) / Double(geo.size.width), 0.0, 1.0)
                                viewModel.playbackProgress = newProgress
                            }
                            .onEnded { value in
                                let newProgress = clamp(Double(value.location.x) / Double(geo.size.width), 0.0, 1.0)
                                viewModel.playbackProgress = newProgress
                                if let file = viewModel.audioFile {
                                    viewModel.pausedFrame = AVAudioFramePosition(newProgress * Double(file.length))
                                    if viewModel.playerNode.isPlaying {
                                        viewModel.seekToCurrentPausedFrameAndResume()
                                    }
                                }
                                viewModel.isSeeking = false
                            }
                    )
                    .simultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = value
                            }
                            .onEnded { value in
                                zoomScale = value
                            }
                    )
                }
                .frame(height: 150)
                
                EQContainerView(eqBands: viewModel.eqBandsFrequencies,
                                eqValues: $viewModel.eqValues,
                                onSliderChanged: viewModel.updateEQ(at:value:),
                                level: viewModel.level,
                                gain: $viewModel.gain)
                    .frame(height: 400)
                
                HStack(spacing: 20) {
                    Button("Play / Pause") {
                        viewModel.togglePlayback()
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                    
                    Button("Select Audio File") {
                        showingPicker = true
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                    
                    Button("Save Preset") {
                        showingSavePreset = true
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                    
                    Button("Load Preset") {
                        showingLoadPreset = true
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                    
                    Button("Playlist") {
                        showingPlaylist = true
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                }
                .padding(.bottom, 40)
                
                Spacer()
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewModel.startAudioEngine()
        }
        .sheet(isPresented: $showingSavePreset) {
            PresetSaveView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingLoadPreset) {
            PresetLoadView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPlaylist) {
            PlaylistView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { urls in
                for url in urls {
                    viewModel.addAudioFileToPlaylist(url: url)
                }
                showingPicker = false
            }
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

