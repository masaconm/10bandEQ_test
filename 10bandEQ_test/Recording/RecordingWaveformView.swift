<<<<<<< HEAD
//
//  RecordingWaveformView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/04/13.
//

import SwiftUI

/// 録音中リアルタイム波形表示ビュー
struct RecordingWaveformView: View {
    @ObservedObject var engineManager: AudioEngineManager
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Recording...")
                .font(.headline)
                .foregroundColor(.red)
                .padding(.bottom, 8)
            
            GeometryReader { geo in
                SmoothWaveformView(
                    sampleBuffer: SampleBuffer(samples: engineManager.microphoneSamples),
                    playbackProgress: 1.0, // 録音時は進行バーなし
=======
import SwiftUI

struct RecordingWaveformView: View {
    @ObservedObject var engineManager: AudioEngineManager
    @Binding var isRecordingMode: Bool

    @State private var hasRecorded = false
    @State private var recordedFileName: String = ""
    @State private var isReadyToPlay = false

    var body: some View {
        VStack(spacing: 0) {
            // 上部タイトル＆録音時間
            VStack(alignment: .leading, spacing: 4) {
                // ✅ モード表示：Monitoring or Recording Mode
                Text(engineManager.isMonitoringOnly ? "Monitoring" : "Recording Mode")
                    .font(.headline)
                    .foregroundColor(.white)

                // ✅ 録音中は録音時間を表示、それ以外は "--"
                if engineManager.isRecording {
                    Text(String(format: "Duration: %.0f sec", engineManager.recordingTime))
                        .font(.subheadline)
                        .foregroundColor(.white)
                } else {
                    Text("Duration: --")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .frame(height: 50)

            // 波形エリア
            GeometryReader { geo in
                SmoothWaveformView(
                    sampleBuffer: SampleBuffer(samples: engineManager.microphoneSamples),
                    playbackProgress: 1.0,
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
                    zoomScale: 1.0
                )
                .environment(\.waveformStyle, .filled)
                .frame(width: geo.size.width, height: geo.size.height)
            }
<<<<<<< HEAD
            .frame(height: 150)
            .background(Color.black)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
=======
            .frame(height: 250)
            .background(Color(hex: "#19191b"))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)

            // Overview 領域（録音状態に応じて切替）
            ZStack {
                if engineManager.isRecording {
                    Color.red.cornerRadius(8).contentShape(Rectangle())
                    VStack(spacing: 2) {
                        Text("Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                    }
                } else if hasRecorded {
                    Color(hex: "#00FFFF").cornerRadius(8).contentShape(Rectangle())
                    VStack(spacing: 2) {
                        Text("Recording saved")
                            .font(.headline)
                            .foregroundColor(.black)
                        Text(recordedFileName)
                            .font(.footnote)
                            .foregroundColor(.black)
                    }
                } else {
                    Color(hex: "#333333").cornerRadius(8).contentShape(Rectangle())
                    VStack(spacing: 2) {
                        Text("Start Recording")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Tap to begin")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 50)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .onTapGesture {
                if engineManager.isRecording {
                    engineManager.stopRecording()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        engineManager.saveRecordingToEQ10Folder()
                        withAnimation {
                            isRecordingMode = false
                        }
                    }
                } else {
                    engineManager.startRecording()
                    hasRecorded = false
                    isReadyToPlay = false
                    recordedFileName = ""
                }
            }

            .allowsHitTesting(true)
            .zIndex(2)
        }
    }
}

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
