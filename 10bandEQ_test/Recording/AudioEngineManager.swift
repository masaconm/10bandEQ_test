<<<<<<< HEAD
// 20250413修正済み AudioEngineManager.swift（+ exportRecordingViaPicker）
=======
//
//  Untitled.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/04/16.
//
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)

import AVFoundation
import AVFAudio
import SwiftUI

extension Notification.Name {
    static let newRecordingFinished = Notification.Name("newRecordingFinished")
}

class AudioEngineManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
<<<<<<< HEAD
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0.0
    @Published var recordedFiles: [String] = []
    @Published var microphoneSamples: [Float] = [] // リアルタイム波形用
    //    @Published var audioEngineManager = AudioEngineManager()
    
=======

    @Published var isRecording = false
    @Published var isMonitoringOnly = false
    @Published var recordingTime: TimeInterval = 0.0
    @Published var recordedFiles: [String] = []
    @Published var microphoneSamples: [Float] = []

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    private var audioRecorder: AVAudioRecorder?
    private var recordingSession = AVAudioSession.sharedInstance()
    private var fileURL: URL?
    private var timer: Timer?
<<<<<<< HEAD
    private var audioEngine = AVAudioEngine()
    
    var lastRecordingURL: URL? {
        return fileURL
    }
    
=======
    var audioEngine = AVAudioEngine()
    private var eqNode: AVAudioUnitEQ?

    var lastRecordingURL: URL? {
        return fileURL
    }

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    override init() {
        super.init()
        setupSession()
        createEQ10FolderIfNeeded()
    }
<<<<<<< HEAD
    
=======

    // MARK: - Audioセッションの初期設定
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    private func setupSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)
<<<<<<< HEAD
            
=======

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
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
<<<<<<< HEAD
            
=======

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        } catch {
            print("録音セッションの設定に失敗しました: \(error.localizedDescription)")
        }
    }
<<<<<<< HEAD
    
    func startRecording() {
        let format = audioEngine.inputNode.inputFormat(forBus: 0)
        audioEngine.inputNode.removeTap(onBus: 0)
        
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processMicrophoneBuffer(buffer: buffer)
        }
        
=======

    // MARK: - モニタリング開始（録音せず波形だけ表示）
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

    // MARK: - 録音開始
    func startRecording() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processMicrophoneBuffer(buffer: buffer)
        }

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine の起動に失敗: \(error.localizedDescription)")
        }
<<<<<<< HEAD
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "record_\(formatter.string(from: Date())).m4a"
        fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
=======

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

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
<<<<<<< HEAD
            startTimer()
            print("録音開始: \(fileURL!.path)")
=======
            isMonitoringOnly = false
            startTimer()
            print("🎙️ 録音開始: \(fileURL!.path)")
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        } catch {
            print("録音開始に失敗: \(error.localizedDescription)")
        }
    }
<<<<<<< HEAD
    
=======

    // MARK: - 録音停止
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
<<<<<<< HEAD
        stopTimer()
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        loadRecordedFiles()
        print("録音停止")
    }
    
    func exportRecordingViaPicker() {
        guard let sourceURL = fileURL else {
            print("録音ファイルが見つかりません")
            return
        }
        
        let picker = UIDocumentPickerViewController(forExporting: [sourceURL])
        picker.shouldShowFileExtensions = true
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }),
           let root = window.rootViewController {
            root.present(picker, animated: true)
        }
    }
    
    func saveRecordingToEQ10Folder() {
        guard let sourceURL = fileURL else {
            print("ファイルURLが存在しません")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "\(formatter.string(from: Date()))_eq10.wav"
        
        let eq10Folder = getDocumentsDirectory().appendingPathComponent("EQ10")
        let destinationURL = eq10Folder.appendingPathComponent(filename)
        
        do {
            try FileManager.default.createDirectory(at: eq10Folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("保存完了: \(destinationURL.lastPathComponent)")
            NotificationCenter.default.post(name: .newRecordingFinished, object: destinationURL)
        } catch {
            print("録音データ保存失敗: \(error)")
        }
    }
    
=======
        isMonitoringOnly = false
        stopTimer()

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        loadRecordedFiles()
        print("⏹️ 録音停止")
    }

    // MARK: - 録音データをEQ10フォルダに保存
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

    // MARK: - マイク波形バッファ処理
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    func processMicrophoneBuffer(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        DispatchQueue.main.async {
            self.microphoneSamples = samples
        }
    }
<<<<<<< HEAD
    
    func loadRecordedFiles() {
=======

    // MARK: - 録音ファイル一覧の取得
    private func loadRecordedFiles() {
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        let fileManager = FileManager.default
        let path = getDocumentsDirectory()
        do {
            let allFiles = try fileManager.contentsOfDirectory(atPath: path.path)
<<<<<<< HEAD
            recordedFiles = allFiles.filter { $0.hasSuffix(".m4a") }.sorted(by: >)
=======
            recordedFiles = allFiles.filter { $0.hasSuffix(".wav") || $0.hasSuffix(".m4a") }.sorted(by: >)
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        } catch {
            print("録音ファイル一覧の読み込み失敗: \(error.localizedDescription)")
        }
    }
<<<<<<< HEAD
    
=======

    // MARK: - タイマー開始
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.recordingTime += 1.0
        }
    }
<<<<<<< HEAD
    
=======

    // MARK: - タイマー停止
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
<<<<<<< HEAD
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
=======

    // MARK: - Documentsフォルダパス取得
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - EQ10フォルダ初回作成
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    private func createEQ10FolderIfNeeded() {
        let eq10Folder = getDocumentsDirectory().appendingPathComponent("EQ10")
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: eq10Folder.path) {
            do {
                try fileManager.createDirectory(at: eq10Folder, withIntermediateDirectories: true)
<<<<<<< HEAD
                print("EQ10フォルダ作成済み: \(eq10Folder.path)")
            } catch {
                print("EQ10フォルダ作成失敗: \(error.localizedDescription)")
            }
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag else {
            print("録音に失敗しました")
            return
        }
        
        waitUntilFileIsReady(url: recorder.url) { isReady in
            if isReady {
                print("録音完了＆ファイル存在 + サイズOK: \(recorder.url.lastPathComponent)")
                NotificationCenter.default.post(name: .newRecordingFinished, object: recorder.url)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // 🔽 0.3秒待機してから表示
                    self.exportRecordingViaPicker()
                }
                
            } else {
                print("録音完了後でもファイルが未準備のため通知スキップ")
            }
        }
    }
    
    
    
    private func waitUntilFileIsReady(url: URL, retries: Int = 5, delay: TimeInterval = 0.2, completion: @escaping (Bool) -> Void) {
        let path = url.path
        let fileManager = FileManager.default
        
=======
                print("📂 EQ10フォルダ作成済み: \(eq10Folder.path)")
            } catch {
                print("❌ EQ10フォルダ作成失敗: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 録音完了後の処理
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

    // MARK: - 録音ファイル準備待機
    private func waitUntilFileIsReady(url: URL, retries: Int = 5, delay: TimeInterval = 0.2, completion: @escaping (Bool) -> Void) {
        let path = url.path
        let fileManager = FileManager.default

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
        func isReady() -> Bool {
            if fileManager.fileExists(atPath: path),
               let attrs = try? fileManager.attributesOfItem(atPath: path),
               let fileSize = attrs[.size] as? UInt64 {
                return fileSize > 1024
            }
            return false
        }
<<<<<<< HEAD
        
=======

>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
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
<<<<<<< HEAD
=======


>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
