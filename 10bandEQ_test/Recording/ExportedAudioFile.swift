import Foundation
import UniformTypeIdentifiers
import SwiftUI
import AVFoundation

enum ExportFormat {
    case wav, mp3_320, mp3_192
}

struct ExportedAudioFile: FileDocument {
    static var readableContentTypes: [UTType] { [.audio] }
    
    let url: URL
    let format: ExportFormat
    
    init(url: URL, format: ExportFormat) {
        self.url = url
        self.format = format
    }
    
    init(configuration: ReadConfiguration) throws {
        self.url = URL(fileURLWithPath: "")
        self.format = .wav
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let tempDir = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let timestamp = dateFormatter.string(from: Date())
        
        let baseName = "\(timestamp)_exported"
        let finalURL: URL
        
        switch format {
        case .wav:
            finalURL = tempDir.appendingPathComponent(baseName).appendingPathExtension("wav")
            
            // 🔁 既存ファイルがあれば削除
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            
            try FileManager.default.copyItem(at: url, to: finalURL)
            return try FileWrapper(url: finalURL, options: .immediate)
            
        case .mp3_320, .mp3_192:
            finalURL = tempDir.appendingPathComponent(baseName).appendingPathExtension("mp3")
            let bitrate: Int32 = (format == .mp3_320) ? 320 : 192
            
            // 🔁 削除してから変換
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            
            try convertToMP3(sourceURL: url, destinationURL: finalURL, bitrate: bitrate)
            
            // 🔄 書き込み確認リトライ（最大10回）
            var retries = 10
            while retries > 0 {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: finalURL.path),
                   let size = attrs[.size] as? UInt64, size > 1024 {
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
                retries -= 1
            }
            
            guard FileManager.default.isReadableFile(atPath: finalURL.path) else {
                throw NSError(domain: "Export", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "MP3 file not ready"
                ])
            }
            
            return try FileWrapper(url: finalURL, options: .immediate)
        }
    }
    
    /// 推奨ファイル名（ダウンロード時に使用）
    var suggestedFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let base = formatter.string(from: Date())
        switch format {
        case .wav: return "\(base)_eq10.wav"
        case .mp3_320: return "\(base)_eq10_320.mp3"
        case .mp3_192: return "\(base)_eq10_192.mp3"
        }
    }
}
