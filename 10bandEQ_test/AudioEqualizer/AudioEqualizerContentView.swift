import SwiftUI
import AVFoundation

enum ActiveSheet: Identifiable {
    case savePreset, loadPreset, playlist, picker, settings, midiMapping
    var id: Int { hashValue }
}

struct AudioEqualizerContentView: View {
    @StateObject var viewModel = AudioEngineViewModel()
    @State private var zoomScale: CGFloat = 1.0
    @State private var activeSheet: ActiveSheet? = nil
    @State private var isLowActive = false
    @State private var isMidActive = false
    @State private var isHighActive = false
    @State private var isRecordingMode = false
    @StateObject var audioEngineManager = AudioEngineManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HeaderView(
                    settingsAction: { activeSheet = .settings },
                    midiMappingAction: { activeSheet = .midiMapping },
                    recordingToggleAction: {
                        isRecordingMode.toggle()
                        if isRecordingMode {
                            audioEngineManager.startMonitoring()
                        } else {
                            audioEngineManager.audioEngine.inputNode.removeTap(onBus: 0)
                            audioEngineManager.audioEngine.stop()
                        }
                    },
                    isRecording: isRecordingMode,
                    audioEngineManager: audioEngineManager
                )
                .frame(height: 80)
                .background(Color(hex: "#1A1A1A"))
                
                if isRecordingMode {
                    RecordingWaveformView(engineManager: audioEngineManager, isRecordingMode: $isRecordingMode)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let current = viewModel.currentPlaylistItem {
                                Text(current.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(String(format: "Duration: %.2f sec", current.duration))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            } else {
                                Text("Audio file not loaded")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .frame(height: 50)
                        
                        GeometryReader { geo in
                            let containerWidth = geo.size.width
                            let containerHeight = geo.size.height
                            let fixedZoomScale: CGFloat = 2.5
                            let waveformWidth = containerWidth * fixedZoomScale
                            let playbackX = CGFloat(viewModel.playbackProgress) * waveformWidth
                            let offsetX = containerWidth / 2 - playbackX
                            
                            ZStack {
                                if viewModel.isLoadingWaveform {
                                    Text("Loading...")
                                        .foregroundColor(.gray)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color(hex: "#19191b"))
                                } else {
                                    ZStack(alignment: .topLeading) {
                                        if let sampleBuffer = viewModel.sampleBuffer {
                                            SmoothWaveformView(
                                                sampleBuffer: sampleBuffer,
                                                playbackProgress: viewModel.playbackProgress,
                                                zoomScale: fixedZoomScale
                                            )
                                            .environment(\.waveformStyle, .filled)
                                            .frame(width: waveformWidth, height: containerHeight)
                                            .offset(x: offsetX)
                                        }
                                        
                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(width: 2, height: containerHeight)
                                            .position(x: containerWidth / 2, y: containerHeight / 2)
                                    }
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        viewModel.isSeeking = true
                                        let newProgress = clamp(Double((value.location.x - containerWidth / 2 + playbackX) / waveformWidth), 0.0, 1.0)
                                        viewModel.playbackProgress = newProgress
                                    }
                                    .onEnded { value in
                                        let newProgress = clamp(Double((value.location.x - containerWidth / 2 + playbackX) / waveformWidth), 0.0, 1.0)
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
                        }
                        .frame(height: 250)
                    }
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    ZStack(alignment: .topLeading) {
                        Color(hex: "#19191b")
                            .frame(height: 50)
                            .padding(.horizontal, 15)
                        
                        if let sampleBuffer = viewModel.sampleBuffer {
                            GeometryReader { overviewGeo in
                                let overviewWidth = overviewGeo.size.width
                                let fixedZoomScale: CGFloat = 2.5
                                
                                ZStack(alignment: .topLeading) {
                                    SmoothWaveformView(
                                        sampleBuffer: sampleBuffer,
                                        playbackProgress: 0,
                                        zoomScale: 1.0
                                    )
                                    .environment(\.waveformStyle, .overview)
                                    .frame(height: 50)
                                    .foregroundColor(Color(hex: "#00FFFF"))
                                    .zIndex(1)
                                    
                                    let indicatorWidth = overviewWidth / fixedZoomScale
                                    let indicatorOffset = CGFloat(viewModel.playbackProgress) * overviewWidth - (indicatorWidth / 2)
                                    
                                    Rectangle()
                                        .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
                                        .background(Color.red.opacity(0.2))
                                        .frame(width: indicatorWidth, height: 50)
                                        .offset(x: indicatorOffset)
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    let newProgress = clamp(Double(value.location.x / overviewWidth), 0.0, 1.0)
                                                    viewModel.playbackProgress = newProgress
                                                }
                                                .onEnded { value in
                                                    let newProgress = clamp(Double(value.location.x / overviewWidth), 0.0, 1.0)
                                                    viewModel.playbackProgress = newProgress
                                                    if let file = viewModel.audioFile {
                                                        viewModel.pausedFrame = AVAudioFramePosition(newProgress * Double(file.length))
                                                        if viewModel.playerNode.isPlaying {
                                                            viewModel.seekToCurrentPausedFrameAndResume()
                                                        }
                                                    }
                                                }
                                        )
                                }
                            }
                            .frame(height: 50)
                        }
                    }
                    .frame(height: 50)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                
                EQContainerView(viewModel: viewModel, activeSheet: $activeSheet)
                    .padding(.horizontal)
                    .frame(height: 400)
                
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !viewModel.audioEngine.isRunning {
                    viewModel.startAudioEngine()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newRecordingFinished)) { notif in
            if let url = notif.object as? URL {
                print("🎯 録音完了ファイル受信: \(url.lastPathComponent)")
                viewModel.addAudioFileToPlaylist(url: url)
            }
        }
        .sheet(item: Binding(get: {
            activeSheet != .picker ? activeSheet : nil
        }, set: { activeSheet = $0 })) { sheet in
            switch sheet {
            case .settings: CombinedSettingsView()
            case .savePreset: PresetSaveView(viewModel: viewModel)
            case .loadPreset: PresetLoadView(viewModel: viewModel)
            case .playlist: PlaylistView(viewModel: viewModel)
            case .midiMapping: MIDIMappingSettingsView(mappings: $viewModel.midiMappings)
            case .picker: EmptyView()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { activeSheet == .picker },
            set: { if !$0 { activeSheet = nil } }
        )) {
            DocumentPicker { urls in
                for url in urls {
                    viewModel.addAudioFileToPlaylist(url: url)
                }
                activeSheet = nil
            }
        }
    }
}

