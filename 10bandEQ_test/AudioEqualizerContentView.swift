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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ヘッダーを最上部に固定し、SafeArea分の余白を追加
                HeaderView(
                    settingsAction: { activeSheet = .settings },
                    midiMappingAction: { activeSheet = .midiMapping }
                )
//                .padding(.top, safeAreaTopInset())
                .frame(height: 80)
                .background(Color(hex: "#1A1A1A"))

                // ファイル情報 + 波形エリア
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
                    .padding(.horizontal)
                    .frame(height: 50)
                    
                    GeometryReader { geo in
                        let containerWidth = geo.size.width
                        let containerHeight = geo.size.height
                        let padding: CGFloat = 10

                        let usableWidth = containerWidth - padding * 2
                        let waveformWidth = usableWidth * zoomScale
                        let playbackX = CGFloat(viewModel.playbackProgress) * waveformWidth
                        let offsetX: CGFloat = waveformWidth > usableWidth ? (usableWidth / 2 - playbackX) : 0
                        let redBarX: CGFloat = waveformWidth > usableWidth ? (usableWidth / 2 + padding) : (playbackX + padding)

//                        ZStack {
//                            ScrollView(.horizontal, showsIndicators: false) {
//                                if let sampleBuffer = viewModel.sampleBuffer {
//                                    SmoothWaveformView(
//                                        sampleBuffer: sampleBuffer,
//                                        playbackProgress: viewModel.playbackProgress,
//                                        zoomScale: zoomScale
//                                    )
//                                    .frame(width: waveformWidth, height: containerHeight)
//                                    .offset(x: offsetX)
//                                } else {
//                                    Text("Audio file not loaded")
//                                        .foregroundColor(.white)
//                                        .frame(width: usableWidth, height: containerHeight)
//                                        .background(Color(hex: "#19191b"))
//                                }
//                            }
//                            .padding(.horizontal, padding)
//
//                            Rectangle()
//                                .fill(Color.red)
//                                .frame(width: 2, height: containerHeight)
//                                .position(x: redBarX, y: containerHeight / 2)
//                        }
                        ZStack {
                            if viewModel.isLoadingWaveform {
                                Text("Loading...")
                                    .foregroundColor(.gray)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color(hex: "#19191b"))
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    if let sampleBuffer = viewModel.sampleBuffer {
                                        SmoothWaveformView(
                                            sampleBuffer: sampleBuffer,
                                            playbackProgress: viewModel.playbackProgress,
                                            zoomScale: zoomScale
                                        )
                                        .frame(width: waveformWidth, height: containerHeight)
                                        .offset(x: offsetX)
                                    } else {
                                        Text("Audio file not loaded")
                                            .foregroundColor(.white)
                                            .frame(width: usableWidth, height: containerHeight)
                                            .background(Color(hex: "#19191b"))
                                    }
                                }

                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 2, height: containerHeight)
                                    .position(x: redBarX, y: containerHeight / 2)
                            }
                        }

                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    viewModel.isSeeking = true
                                    let newProgress = waveformWidth > usableWidth
                                        ? clamp(Double(value.location.x - offsetX - padding) / Double(waveformWidth), 0.0, 1.0)
                                        : clamp(Double(value.location.x - padding) / Double(usableWidth), 0.0, 1.0)
                                    viewModel.playbackProgress = newProgress
                                }
                                .onEnded { value in
                                    let newProgress = waveformWidth > usableWidth
                                        ? clamp(Double(value.location.x - offsetX - padding) / Double(waveformWidth), 0.0, 1.0)
                                        : clamp(Double(value.location.x - padding) / Double(usableWidth), 0.0, 1.0)
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
                        // 👇 ピンチ（拡大）は完全に無効化
                        // .simultaneousGesture(...) 削除済み
                    }
                    .frame(height: 150)

                }
                .background(Color(hex: "#19191b"))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 20)

                EQContainerView(viewModel: viewModel, activeSheet: $activeSheet)
                    .padding(.horizontal)
                    .frame(height: 550)

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

    /// SafeAreaトップの高さを取得（iOS 15以降の推奨スタイル）
    private func safeAreaTopInset() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 20
    }
}

