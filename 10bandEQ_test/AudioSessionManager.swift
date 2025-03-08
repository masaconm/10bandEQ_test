//
//  AudioSessionManager.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/07.
//
import AVFoundation

class AudioSessionManager {
    static func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // playAndRecordカテゴリを使用し、BluetoothやA2DP、スピーカー出力を許可
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            // 推奨サンプルレートを設定（例：48000Hz）
            try session.setPreferredSampleRate(48000)
            try session.setActive(true)
            print("Audio session configured successfully.")
        } catch {
            print("Error configuring audio session: \(error.localizedDescription)")
        }
    }
}

