//AudioEqualizerContentView.swift

import SwiftUI
import AVFoundation

enum ActiveSheet: Identifiable {
    case savePreset, loadPreset, playlist, picker, settings, midiMapping
    var id: Int { hashValue }
}

struct AudioEqualizerContentView: View {
    @StateObject var viewModel = AudioEngineViewModel()
    @State private var zoomScale: CGFloat = 1.0
    // 各シート表示用の状態
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー：Settings ボタン（例）※必要に応じて変更
            HeaderView(settingsAction: {
                activeSheet = .settings  // ここを .settings に変更
            })

            .frame(height: 60)
            
            // 現在再生中の音声ファイル情報表示
            // 常に高さを確保し、未読み込み時はプレースホルダー表示
            VStack(spacing: 0) {
                // 再生中のファイル情報エリア
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

                // 波形表示エリア
                GeometryReader { geo in
                    let containerWidth = geo.size.width
                    let containerHeight = geo.size.height
                    let waveformWidth = containerWidth * zoomScale
                    let playbackX = CGFloat(viewModel.playbackProgress) * waveformWidth
                    let offsetX: CGFloat = waveformWidth > containerWidth ? (containerWidth / 2 - playbackX) : 0
                    let redBarX: CGFloat = waveformWidth > containerWidth ? (containerWidth / 2) : playbackX

                    ZStack {
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
                                    .frame(width: containerWidth, height: containerHeight)
                                    .background(Color(hex: "#19191b")) // ← ここを変更
                            }
                        }

                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: containerHeight)
                            .position(x: redBarX, y: containerHeight / 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                viewModel.isSeeking = true
                                let newProgress: Double
                                if waveformWidth > containerWidth {
                                    newProgress = clamp(Double(value.location.x - offsetX) / Double(waveformWidth), 0.0, 1.0)
                                } else {
                                    newProgress = clamp(Double(value.location.x) / Double(containerWidth), 0.0, 1.0)
                                }
                                viewModel.playbackProgress = newProgress
                            }
                            .onEnded { value in
                                let newProgress: Double
                                if waveformWidth > containerWidth {
                                    newProgress = clamp(Double(value.location.x - offsetX) / Double(waveformWidth), 0.0, 1.0)
                                } else {
                                    newProgress = clamp(Double(value.location.x) / Double(containerWidth), 0.0, 1.0)
                                }
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
            }
            .background(Color(hex: "#19191b"))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)
            
// MARK: -EQ、GAIN、Level メーター表示
//            EQContainerView(eqBands: viewModel.eqBandsFrequencies,
//                            eqValues: $viewModel.eqValues,
//                            onSliderChanged: viewModel.updateEQ(at:value:),
//                            level: viewModel.level,
//                            gain: $viewModel.gain)
            EQContainerView(viewModel: viewModel)

                .frame(height: 400)
            
            // 各シート表示用の操作ボタン群（ここに MIDI Mapping ボタンを追加）
            HStack(spacing: 20) {
//                Button("Play / Pause") { viewModel.togglePlayback() }
//                    .padding()
//                    .background(Color.white)
//                    .cornerRadius(5)
                Button("Select Audio File") { activeSheet = .picker }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                Button("Save Preset") { activeSheet = .savePreset }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                Button("Load Preset") { activeSheet = .loadPreset }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                Button("Playlist") { activeSheet = .playlist }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                Button("MIDI Mapping") { activeSheet = .midiMapping }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            if !viewModel.audioEngine.isRunning {
                viewModel.startAudioEngine()
            }
        }
        // 各種シートの表示
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                CombinedSettingsView()  // ここを CombinedSettingsView() に変更
            case .savePreset:
                PresetSaveView(viewModel: viewModel)
            case .loadPreset:
                PresetLoadView(viewModel: viewModel)
            case .playlist:
                PlaylistView(viewModel: viewModel)
            case .picker:
                DocumentPicker { urls in
                    for url in urls {
                        viewModel.addAudioFileToPlaylist(url: url)
                    }
                    activeSheet = nil
                }
            case .midiMapping:
                MIDIMappingSettingsView(mappings: $viewModel.midiMappings)
            }
        }

    }
}

