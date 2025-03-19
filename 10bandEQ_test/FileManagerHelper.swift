//
//  FileManagerHelper.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/19.
//

import Foundation

class FileManagerHelper {
    static func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static func saveAudioFile(fileName: String) -> URL {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        print("保存先: \(fileURL)")
        return fileURL
    }

    static func copyFileToDocuments(url: URL) -> URL? {
        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(url.lastPathComponent)
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: url, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to copy file: \(error)")
            return nil
        }
    }
}
