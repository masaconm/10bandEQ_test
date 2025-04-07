//AudioEngineManager.swift
//実装テスト中だがうまくいかない 3/23

import AVFoundation
import AVFAudio
import SwiftUI

// Notification 名前の定義（グローバル）
extension Notification.Name {
    static let newRecordingFinished = Notification.Name("newRecordingFinished")
}


class AudioEngineManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0.0
    @Published var recordedFiles: [String] = []

    private var audioRecorder: AVAudioRecorder?
    private var recordingSession = AVAudioSession.sharedInstance()
    private var fileURL: URL?
    private var timer: Timer?

    /// 外部アクセス用：直近の録音ファイルURL
    var lastRecordingURL: URL? {
        return fileURL
    }

    override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try recordingSession.setActive(true)

            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission(completionHandler: { granted in
                    if !granted {
                        print("❌ マイクのアクセスが拒否されました (iOS 17)")
                    }
                })
            } else {
                recordingSession.requestRecordPermission { granted in
                    if !granted {
                        print("❌ マイクのアクセスが拒否されました (iOS 16 以下)")
                    }
                }
            }

        } catch {
            print("❌ 録音セッションの設定に失敗しました: \(error.localizedDescription)")
        }
    }

    func startRecording() {
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

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
            startTimer()
            print("🎤 録音開始: \(fileURL!.path)")
        } catch {
            print("❌ 録音開始に失敗: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopTimer()
        loadRecordedFiles()
        print("🛑 録音停止")
        // 通知は delegate メソッドで送るのでここでは不要
    }

    func loadRecordedFiles() {
        let fileManager = FileManager.default
        let path = getDocumentsDirectory()
        do {
            let allFiles = try fileManager.contentsOfDirectory(atPath: path.path)
            recordedFiles = allFiles.filter { $0.hasSuffix(".m4a") }.sorted(by: >)
        } catch {
            print("❌ 録音ファイル一覧の読み込み失敗: \(error.localizedDescription)")
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

    // デリゲートで録音完了後に通知を送信
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag else {
            print("❌ 録音に失敗しました")
            return
        }

        // ファイル存在チェック + サイズ確認付き
        waitUntilFileIsReady(url: recorder.url) { isReady in
            if isReady {
                print("✅ 録音完了＆ファイル存在 + サイズOK: \(recorder.url.lastPathComponent)")
                NotificationCenter.default.post(name: .newRecordingFinished, object: recorder.url)
            } else {
                print("⚠️ 録音完了後でもファイルが未準備のため通知スキップ")
            }
        }
    }

    /// ファイルの存在＋サイズが0以上になるまでリトライ（最大5回）
    private func waitUntilFileIsReady(url: URL, retries: Int = 5, delay: TimeInterval = 0.2, completion: @escaping (Bool) -> Void) {
        let path = url.path
        let fileManager = FileManager.default

        func isReady() -> Bool {
            if fileManager.fileExists(atPath: path),
               let attrs = try? fileManager.attributesOfItem(atPath: path),
               let fileSize = attrs[.size] as? UInt64 {
                return fileSize > 1024 // 1KB以上ならOK（空ファイルでないこと）
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
