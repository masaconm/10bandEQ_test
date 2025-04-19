//
//  AudioEngineManager.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/04/13.
//

import AVFoundation
import AVFAudio
import SwiftUI

extension Notification.Name {
    static let newRecordingFinished = Notification.Name("newRecordingFinished")
}

class AudioEngineManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var isMonitoringOnly = false
    @Published var recordingTime: TimeInterval = 0.0
    @Published var recordedFiles: [String] = []
    @Published var microphoneSamples: [Float] = []

    private var audioRecorder: AVAudioRecorder?
    private var recordingSession = AVAudioSession.sharedInstance()
    private var fileURL: URL?
    private var timer: Timer?
    var audioEngine = AVAudioEngine()
    private var eqNode: AVAudioUnitEQ?

    var lastRecordingURL: URL? {
        return fileURL
    }

    override init() {
        super.init()
        setupSession()
        createEQ10FolderIfNeeded()
    }

    private func setupSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)

            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    if !granted {
                        print("マイクのアクセスが拒否されました (iOS 17)")
                    }
                }
            } else {
                recordingSession.requestRecordPermission { granted in
                    if !granted {
                        print("マイクのアクセスが拒否されました (iOS 16 以下)")
                    }
                }
            }
        } catch {
            print("録音セッションの設定に失敗しました: \(error.localizedDescription)")
        }
    }

    func startMonitoring() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processMicrophoneBuffer(buffer: buffer)
        }

        do {
            try audioEngine.start()
            isMonitoringOnly = true
            print("✅ Monitoring started")
        } catch {
            print("❌ Monitoring failed to start: \(error)")
        }
    }

    func startRecording() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processMicrophoneBuffer(buffer: buffer)
        }

        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine の起動に失敗: \(error.localizedDescription)")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "record_\(formatter.string(from: Date())).wav"
        fileURL = getDocumentsDirectory().appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            isMonitoringOnly = false
            startTimer()
            print("🎙️ 録音開始: \(fileURL!.path)")
        } catch {
            print("録音開始に失敗: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        isMonitoringOnly = false
        stopTimer()

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        loadRecordedFiles()
        print("⏹️ 録音停止")
    }

    func saveRecordingToEQ10Folder() {
        guard let sourceURL = fileURL else {
            print("⚠️ fileURLがnilです。録音ソースが見つかりません")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let filename = "\(formatter.string(from: Date()))_eq10.wav"

        let eq10Folder = getDocumentsDirectory().appendingPathComponent("EQ10")
        let destinationURL = eq10Folder.appendingPathComponent(filename)

        do {
            try FileManager.default.createDirectory(at: eq10Folder, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            self.fileURL = destinationURL

            print("✅ 保存完了: \(destinationURL.lastPathComponent)")
            print("📌 保存先URL: \(destinationURL.path)")

            let contents = try FileManager.default.contentsOfDirectory(atPath: eq10Folder.path)
            print("📁 EQ10フォルダ内容:")
            contents.forEach { print(" - \($0)") }

        } catch {
            print("❌ 録音データ保存失敗: \(error)")
        }
    }

    func processMicrophoneBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        DispatchQueue.main.async {
            self.microphoneSamples = samples
        }
    }

    private func loadRecordedFiles() {
        let fileManager = FileManager.default
        let path = getDocumentsDirectory()
        do {
            let allFiles = try fileManager.contentsOfDirectory(atPath: path.path)
            recordedFiles = allFiles.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") }.sorted(by: >)
        } catch {
            print("録音ファイル一覧の読み込み失敗: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.recordingTime += 1.0
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private func createEQ10FolderIfNeeded() {
        let eq10Folder = getDocumentsDirectory().appendingPathComponent("EQ10")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: eq10Folder.path) {
            do {
                try fileManager.createDirectory(at: eq10Folder, withIntermediateDirectories: true)
                print("📂 EQ10フォルダ作成済み: \(eq10Folder.path)")
            } catch {
                print("❌ EQ10フォルダ作成失敗: \(error.localizedDescription)")
            }
        }
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            waitUntilFileIsReady(url: recorder.url) { isReady in
                if isReady {
                    DispatchQueue.main.async {
                        self.saveRecordingToEQ10Folder()
                        NotificationCenter.default.post(name: .newRecordingFinished, object: self.lastRecordingURL)
                    }
                }
            }
        }
    }

    private func waitUntilFileIsReady(url: URL, retries: Int = 5, delay: TimeInterval = 0.2, completion: @escaping (Bool) -> Void) {
        let path = url.path
        let fileManager = FileManager.default

        func isReady() -> Bool {
            if fileManager.fileExists(atPath: path),
               let attrs = try? fileManager.attributesOfItem(atPath: path),
               let fileSize = attrs[.size] as? UInt64 {
                return fileSize > 1024
            }
            return false
        }

        if isReady() {
            completion(true)
        } else if retries > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.waitUntilFileIsReady(url: url, retries: retries - 1, delay: delay, completion: completion)
            }
        } else {
            completion(false)
        }
    }
}
