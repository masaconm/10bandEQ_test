////
////  Untitled.swift
////  10bandEQ_test
////
////  Created by 中静暢子 on 2025/04/13.
////
//
//// 20250413改修 AudioEngineManager.swift
//
//import AVFoundation
//import AVFAudio
//import SwiftUI
//
//extension Notification.Name {
//    static let newRecordingFinished = Notification.Name("newRecordingFinished")
//}
//
//class AudioEngineManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
//    @Published var isRecording = false
//    @Published var recordingTime: TimeInterval = 0.0
//    @Published var recordedFiles: [String] = []
//    @Published var microphoneSamples: [Float] = [] // リアルタイム波形用
//    
//    private var audioRecorder: AVAudioRecorder?
//    private var recordingSession = AVAudioSession.sharedInstance()
//    private var fileURL: URL?
//    private var timer: Timer?
//    private var audioEngine = AVAudioEngine()
//    
//    var lastRecordingURL: URL? {
//        return fileURL
//    }
//    
//    override init() {
//        super.init()
//        setupSession()
//        createEQ10FolderIfNeeded()
//    }
//    
//    private func setupSession() {
//        do {
//            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
//            try recordingSession.setActive(true)
//            
//            if #available(iOS 17.0, *) {
//                AVAudioApplication.requestRecordPermission { granted in
//                    if !granted {
//                        print("❌ マイクのアクセスが拒否されました (iOS 17)")
//                    }
//                }
//            } else {
//                recordingSession.requestRecordPermission { granted in
//                    if !granted {
//                        print("❌ マイクのアクセスが拒否されました (iOS 16 以下)")
//                    }
//                }
//            }
//            
//        } catch {
//            print("❌ 録音セッションの設定に失敗しました: \(error.localizedDescription)")
//        }
//    }
//    
//    func startRecording() {
//        let format = audioEngine.inputNode.inputFormat(forBus: 0)
//        audioEngine.inputNode.removeTap(onBus: 0)
//        
//        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
//            guard let self = self else { return }
//            self.processMicrophoneBuffer(buffer: buffer)
//        }
//        
//        do {
//            try audioEngine.start()
//        } catch {
//            print("❌ AudioEngine の起動に失敗: \(error.localizedDescription)")
//        }
//        
//        func saveRecordingToEQ10Folder() {
//            guard let sourceURL = fileURL else {
//                print("❌ ファイルURLが存在しません")
//                return
//            }
//            
//            let formatter = DateFormatter()
//            formatter.dateFormat = "yyyyMMdd_HHmmss"
//            let filename = "\(formatter.string(from: Date()))_eq10.wav"
//            
//            let eq10Folder = getDocumentsDirectory().appendingPathComponent("EQ10")
//            let destinationURL = eq10Folder.appendingPathComponent(filename)
//            
//            do {
//                try FileManager.default.createDirectory(at: eq10Folder, withIntermediateDirectories: true)
//                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
//                print("✅ 保存完了: \(destinationURL.lastPathComponent)")
//                NotificationCenter.default.post(name: .newRecordingFinished, object: destinationURL)
//            } catch {
//                print("❌ 録音データ保存失敗: \(error)")
//            }
//        }
//        
//    }
//    
//    func processMicrophoneBuffer(buffer: AVAudioPCMBuffer) {
//        guard let channelData = buffer.floatChannelData?[0] else { return }
//        let frameLength = Int(buffer.frameLength)
//        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
//        DispatchQueue.main.async {
//            self.microphoneSamples = samples
//        }
//    }
//    
//    func loadRecordedFiles() {
//        let fileManager = FileManager.default
//        let path = getDocumentsDirectory()
//        do {
//            let allFiles = try fileManager.contentsOfDirectory(atPath: path.path)
//            recordedFiles = allFiles.filter { $0.hasSuffix(".m4a") }.sorted(by: >)
//        } catch {
//            print("❌ 録音ファイル一覧の読み込み失敗: \(error.localizedDescription)")
//        }
//    }
//    
//    private func startTimer() {
//        recordingTime = 0
//        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
//            self.recordingTime += 1.0
//        }
//    }
//    
//    private func stopTimer() {
//        timer?.invalidate()
//        timer = nil
//    }
//    
//    func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//    }
//    
//    private func createEQ10FolderIfNeeded() {
//        let eq10Folder = getDocumentsDirectory().appendingPathComponent("EQ10")
//        let fileManager = FileManager.default
//        if !fileManager.fileExists(atPath: eq10Folder.path) {
//            do {
//                try fileManager.createDirectory(at: eq10Folder, withIntermediateDirectories: true)
//                print("📁 EQ10フォルダ作成済み: \(eq10Folder.path)")
//            } catch {
//                print("❌ EQ10フォルダ作成失敗: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
//        guard flag else {
//            print("❌ 録音に失敗しました")
//            return
//        }
//        
//        waitUntilFileIsReady(url: recorder.url) { isReady in
//            if isReady {
//                print("✅ 録音完了＆ファイル存在 + サイズOK: \(recorder.url.lastPathComponent)")
//                NotificationCenter.default.post(name: .newRecordingFinished, object: recorder.url)
//            } else {
//                print("⚠️ 録音完了後でもファイルが未準備のため通知スキップ")
//            }
//        }
//    }
//    
//    private func waitUntilFileIsReady(url: URL, retries: Int = 5, delay: TimeInterval = 0.2, completion: @escaping (Bool) -> Void) {
//        let path = url.path
//        let fileManager = FileManager.default
//        
//        func isReady() -> Bool {
//            if fileManager.fileExists(atPath: path),
//               let attrs = try? fileManager.attributesOfItem(atPath: path),
//               let fileSize = attrs[.size] as? UInt64 {
//                return fileSize > 1024
//            }
//            return false
//        }
//        
//        if isReady() {
//            completion(true)
//        } else if retries > 0 {
//            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
//                self.waitUntilFileIsReady(url: url, retries: retries - 1, delay: delay, completion: completion)
//            }
//        } else {
//            completion(false)
//        }
//    }
//}
//
