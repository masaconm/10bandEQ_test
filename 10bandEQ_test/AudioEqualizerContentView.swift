//
//  AudioEqualizerContentView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/08.
//
import SwiftUI
import AVFoundation

// ActiveSheet の定義（ここに定義しても、共通ファイルにしてもOK）
enum ActiveSheet: Identifiable {
    case savePreset, loadPreset, playlist, picker, audioSettings, midiMapping
    var id: Int { hashValue }
}

struct AudioEqualizerContentView: View {
    @StateObject var viewModel = AudioEngineViewModel()
    @State private var zoomScale: CGFloat = 1.0
    // activeSheet によって、どのシートを表示するかを管理する
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー部分。Audio Settings ボタンのタップで activeSheet を .audioSettings に変更
            HeaderView(currentLanguage: $viewModel.currentLanguage, audioSettingsAction: {
                activeSheet = .audioSettings
            })
            .frame(height: 60)
            
            // 現在再生中の音声ファイル情報の表示
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
            
            // 波形表示領域
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
                                .background(Color.gray)
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
            
            // 拡大縮小ボタン
            HStack(spacing: 20) {
                Button(action: {
                    zoomScale = max(zoomScale / 1.2, 0.5)
                }) {
                    Text("–")
                        .font(.largeTitle)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                Button(action: {
                    zoomScale = zoomScale * 1.2
                }) {
                    Text("+")
                        .font(.largeTitle)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
            
            // EQ、GAIN、Level メーター
            EQContainerView(eqBands: viewModel.eqBandsFrequencies,
                            eqValues: $viewModel.eqValues,
                            onSliderChanged: viewModel.updateEQ(at:value:),
                            level: viewModel.level,
                            gain: $viewModel.gain)
                .frame(height: 400)
            
            // 各シート表示用の操作ボタン群
            HStack(spacing: 20) {
                Button("Play / Pause") {
                    viewModel.togglePlayback()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(5)
                
                Button("Select Audio File") {
                    activeSheet = .picker
                }
                .padding()
                .background(Color.white)
                .cornerRadius(5)
                
                Button("Save Preset") {
                    activeSheet = .savePreset
                }
                .padding()
                .background(Color.white)
                .cornerRadius(5)
                
                Button("Load Preset") {
                    activeSheet = .loadPreset
                }
                .padding()
                .background(Color.white)
                .cornerRadius(5)
                
                Button("Playlist") {
                    activeSheet = .playlist
                }
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
            // ビューが表示されたとき、AudioEngine が動作していなければ起動
            if !viewModel.audioEngine.isRunning {
                viewModel.startAudioEngine()
            }
        }
        // activeSheet に応じたシートを 1 つの .sheet モディファイアで表示
        .sheet(item: $activeSheet) { (sheet: ActiveSheet) in
            switch sheet {
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
            case .audioSettings:
                AudioInterfaceSettingsView()
            case .midiMapping:
                MIDIMappingSettingsView(mappings: $viewModel.midiMappings)
            }
        }
    }
}

