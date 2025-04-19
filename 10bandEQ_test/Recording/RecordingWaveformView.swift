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
    @Binding var isRecordingMode: Bool

    @State private var hasRecorded = false
    @State private var recordedFileName: String = ""
    @State private var isReadyToPlay = false

    var body: some View {
        VStack(spacing: 0) {
            // 上部タイトル＆録音時間表示
            VStack(alignment: .leading, spacing: 4) {
                Text(engineManager.isMonitoringOnly ? "Monitoring" : "Recording Mode")
                    .font(.headline)
                    .foregroundColor(.white)

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

            // 波形描画エリア
            GeometryReader { geo in
                SmoothWaveformView(
                    sampleBuffer: SampleBuffer(samples: engineManager.microphoneSamples),
                    playbackProgress: 1.0,
                    zoomScale: 1.0
                )
                .environment(\.waveformStyle, .filled)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 250)
            .background(Color(hex: "#19191b"))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 8)

            // 録音状態の表示と操作
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
                        hasRecorded = true
                        recordedFileName = engineManager.lastRecordingURL?.lastPathComponent ?? ""
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

