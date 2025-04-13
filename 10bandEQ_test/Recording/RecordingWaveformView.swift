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
                    zoomScale: 1.0
                )
                .environment(\.waveformStyle, .filled)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 150)
            .background(Color.black)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
}
