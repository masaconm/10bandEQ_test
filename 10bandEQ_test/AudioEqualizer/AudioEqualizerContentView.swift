import SwiftUI
import AVFoundation

// シートで表示するビューの種類を列挙（設定、プリセット保存・読込、プレイリストなど）
enum ActiveSheet: Identifiable {
    case savePreset, loadPreset, playlist, picker, settings, midiMapping
    var id: Int { hashValue } // Identifiable 準拠用に一意なIDを提供
}

struct AudioEqualizerContentView: View {
    // Audio処理全般を担う ViewModel（EQ・再生・シーク等）
    @StateObject var viewModel = AudioEngineViewModel()
    
    // 波形のズーム倍率（現在は固定で使用）
    @State private var zoomScale: CGFloat = 1.0
    
    // 表示中のシート（モーダルビュー）を管理
    @State private var activeSheet: ActiveSheet? = nil
    
    // LOW / MID / HIGH のフィルター選択状態（UI切り替え用）
    @State private var isLowActive = false
    @State private var isMidActive = false
    @State private var isHighActive = false
    
    // 録音モードの状態（波形表示を切り替える）
    @State private var isRecordingMode = false
    
    // 録音制御用のオーディオマネージャー（録音・停止・エクスポート）
    @StateObject var audioEngineManager = AudioEngineManager()
    
    var body: some View {
        ZStack {
            // 背景を黒で全画面塗りつぶし
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー：設定 / MIDIマッピング / 録音トグルボタンを含む
                HeaderView(
                    settingsAction: { activeSheet = .settings },
                    midiMappingAction: { activeSheet = .midiMapping },
                    
                    // 録音トグルアクション
                    recordingToggleAction: {
                        if isRecordingMode {
                            audioEngineManager.stopRecording()
                            audioEngineManager.exportRecordingViaPicker() // 録音後にファイルエクスポートを促す
                        } else {
                            audioEngineManager.startRecording()
                        }
                        isRecordingMode.toggle()
                    },
                    
                    // 録音中かどうかの状態バインディング
                    isRecording: isRecordingMode,
                    
                    // AudioEngineManager 全体をヘッダーに渡す
                    audioEngineManager: audioEngineManager
                )
                .frame(height: 80)
                .background(Color(hex: "#1A1A1A"))
                
                // 録音モード中は録音波形を表示、それ以外は再生波形ビュー
                if isRecordingMode {
                    RecordingWaveformView(engineManager: audioEngineManager)
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        // 現在の再生中ファイルの情報（タイトル・長さ）
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
                        
                        // メイン波形ビュー：中央固定の赤バーに対して波形が左右にスクロール
                        GeometryReader { geo in
                            let containerWidth = geo.size.width
                            let containerHeight = geo.size.height
                            let fixedZoomScale: CGFloat = 2.5
                            let waveformWidth = containerWidth * fixedZoomScale
                            let playbackX = CGFloat(viewModel.playbackProgress) * waveformWidth
                            let offsetX = containerWidth / 2 - playbackX
                            
                            ZStack {
                                if viewModel.isLoadingWaveform {
                                    // ローディング中の表示
                                    Text("Loading...")
                                        .foregroundColor(.gray)
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color(hex: "#19191b"))
                                } else {
                                    ZStack(alignment: .topLeading) {
                                        if let sampleBuffer = viewModel.sampleBuffer {
                                            // 波形描画ビュー
                                            SmoothWaveformView(
                                                sampleBuffer: sampleBuffer,
                                                playbackProgress: viewModel.playbackProgress,
                                                zoomScale: fixedZoomScale
                                            )
                                            .environment(\.waveformStyle, .filled)
                                            .frame(width: waveformWidth, height: containerHeight)
                                            .offset(x: offsetX) // 再生位置を中央に表示
                                        }
                                        
                                        // 再生位置バー（中央に固定）
                                        Rectangle()
                                            .fill(Color.red)
                                            .frame(width: 2, height: containerHeight)
                                            .position(x: containerWidth / 2, y: containerHeight / 2)
                                    }
                                }
                            }
                            // ドラッグによる再生位置移動（シーク）
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
                    
                    // 全体波形の概観（Overview）
                    ZStack(alignment: .topLeading) {
                        Color(hex: "#19191b")
                            .frame(height: 50)
                            .padding(.horizontal, 15)
                        
                        if let sampleBuffer = viewModel.sampleBuffer {
                            GeometryReader { overviewGeo in
                                let overviewWidth = overviewGeo.size.width
                                let fixedZoomScale: CGFloat = 2.5
                                
                                ZStack(alignment: .topLeading) {
                                    // 全体波形（ズームアウト表示）
                                    SmoothWaveformView(
                                        sampleBuffer: sampleBuffer,
                                        playbackProgress: 0,
                                        zoomScale: 1.0
                                    )
                                    .environment(\.waveformStyle, .overview)
                                    .frame(height: 50)
                                    .background(Color.clear)
                                    .foregroundColor(Color(hex: "#00FFFF"))
                                    .zIndex(1)
                                    
                                    // 現在再生中の位置を示す矩形インジケータ
                                    let indicatorWidth = overviewWidth / fixedZoomScale
                                    let indicatorOffset = CGFloat(viewModel.playbackProgress) * overviewWidth - (indicatorWidth / 2)
                                    
                                    Rectangle()
                                        .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
                                        .background(Color.red.opacity(0.2))
                                        .frame(width: indicatorWidth, height: 50)
                                        .offset(x: indicatorOffset)
                                        .gesture(
                                            // ドラッグでシーク操作（概観波形）
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
                
                // EQスライダー群や録音・再生ボタンを内包するメイン操作パネル
                EQContainerView(viewModel: viewModel, activeSheet: $activeSheet)
                    .padding(.horizontal)
                    .frame(height: 400)
                
                Spacer()
            }
        }
        // 起動後に AudioEngine をスタート（ディレイありで非同期に）
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !viewModel.audioEngine.isRunning {
                    viewModel.startAudioEngine()
                }
            }
        }
        // シート表示（プリセット保存・読込など）
        .sheet(item: Binding(
            get: { activeSheet != .picker ? activeSheet : nil },
            set: { activeSheet = $0 }
        )) { sheet in
            switch sheet {
            case .settings: CombinedSettingsView()
            case .savePreset: PresetSaveView(viewModel: viewModel)
            case .loadPreset: PresetLoadView(viewModel: viewModel)
            case .playlist: PlaylistView(viewModel: viewModel)
            case .midiMapping: MIDIMappingSettingsView(mappings: $viewModel.midiMappings)
            case .picker: EmptyView()
            }
        }
        // ドキュメントピッカー（録音データエクスポート）
        .fullScreenCover(
            isPresented: Binding(
                get: { activeSheet == .picker },
                set: { if !$0 { activeSheet = nil } }
            )
        ) {
            DocumentPicker { urls in
                for url in urls {
                    viewModel.addAudioFileToPlaylist(url: url)
                }
                activeSheet = nil
            }
        }
    }
}

