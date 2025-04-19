//
//  AudioEqualizerViewController.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/02/24.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
// Waveform ライブラリは、SmoothWaveformView で独自実装するため不要


// MARK: - SampleBuffer
/// 波形表示用のサンプル配列を保持する構造体
struct SampleBuffer {
    var samples: [Float]
}

// MARK: - EQPreset
/// EQ プリセットのデータ構造。ユーザーが設定した EQ の各バンドの値を保持する。
/// Codable に準拠しているので、JSON での保存／読み込みが可能。
/// EQPreset に filterType 情報を含める（拡張）
struct EQPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var eqValues: [Float]
    var filterTypeRawValues: [Int]?
    
    init(name: String, eqValues: [Float], filterTypes: [AVAudioUnitEQFilterType]? = nil) {
        self.id = UUID()
        self.name = name
        self.eqValues = eqValues
        self.filterTypeRawValues = filterTypes?.map { $0.rawValue }
    }
    
    var filterTypes: [AVAudioUnitEQFilterType]? {
        filterTypeRawValues?.compactMap { AVAudioUnitEQFilterType(rawValue: $0) }
    }
}

// MARK: - PlaylistItem
/// プレイリストに追加される音声ファイルの情報を保持する構造体
/// URL、タイトル、再生時間（秒）を含み、Codable に準拠しているので永続保存が可能。
struct PlaylistItem: Identifiable, Codable {
    var id = UUID()
    let url: URL
    let title: String
    let duration: Double  // seconds
    
    /// 指定した URL から AVAudioFile を読み込み、再生時間などを計算して初期化する。
    init?(url: URL) {
        self.url = url
        self.title = url.lastPathComponent
        do {
            let file = try AVAudioFile(forReading: url)
            let sampleRate = file.processingFormat.sampleRate
            self.duration = Double(file.length) / sampleRate
        } catch {
            print("Failed to load file for duration: \(error)")
            return nil
        }
    }
}

// MARK: - DocumentPicker
/// UIDocumentPickerViewController を SwiftUI で利用するための UIViewControllerRepresentable
/// ユーザーが音声ファイルを選択するために使用する。
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // UTType.audio により音声ファイルを選択対象に
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.audio], asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = true
        controller.modalPresentationStyle = .formSheet
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    // Coordinator は UIDocumentPickerDelegate を実装し、選択結果を onPick クロージャに渡す
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// MARK: - グローバル関数：ファイルを Documents ディレクトリにコピーする
/// 選択されたファイルを永続保存可能な場所（Documents ディレクトリ）にコピーする関数。
func copyFileToDocuments(url: URL) -> URL? {
    let fileManager = FileManager.default
    // Documents ディレクトリの取得
    guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }
    let destinationURL = documentsDir.appendingPathComponent(url.lastPathComponent)
    do {
        // 同名のファイルが存在すれば削除
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        // コピー実行
        try fileManager.copyItem(at: url, to: destinationURL)
        return destinationURL
    } catch {
        print("Failed to copy file: \(error)")
        return nil
    }
}

// MARK: - Custom Slider Components
//-つまみ部分：固定サイズの正方形
struct SliderThumb: View {
    var thumbWidth: CGFloat = 50
    var thumbHeight: CGFloat = 30
    var thumbColor: Color = Color(hex: "#363739")
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(thumbColor)
            
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(hex: "#1f2022"), lineWidth: 2)
            
            Rectangle()
                .fill(Color(hex: "#858585"))
                .frame(width: thumbWidth * 0.6, height: 2) // ✅ 横線！
        }
        .frame(width: thumbWidth, height: thumbHeight)
        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
}

// MARK: - カスタム Vertical Slider：つまみとトラックを個別に描画する縦型スライダー
struct CustomVerticalSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var thumbWidth: CGFloat = 40          // 横幅
    var thumbHeight: CGFloat = 30         // 高さ
    var trackColor: Color = .black
    var fillColor: Color = .blue
    var thumbColor: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let fillHeight = height * percentage
            let thumbY = height * (1 - percentage)
            
            ZStack {
                SliderTrack(
                    percentage: fillHeight,
                    width: width,
                    height: height,
                    trackColor: trackColor,
                    fillColor: fillColor
                )
                
                SliderThumb(
                    thumbWidth: thumbWidth,
                    thumbHeight: thumbHeight,
                    thumbColor: thumbColor
                )
                .position(x: width / 2, y: thumbY)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let clampedY = min(max(gesture.location.y, 0), height)
                            let newPercentage = 1 - (clampedY / height)
                            let newValue = range.lowerBound + Float(newPercentage) * (range.upperBound - range.lowerBound)
                            self.value = newValue
                        }
                )
            }
        }
    }
}

//    // MARK: - Preview
struct AudioEqualizerContentView_Previews: PreviewProvider {
    static var previews: some View {
        AudioEqualizerContentView()
            .environmentObject(AudioEngineViewModel())
            .previewInterfaceOrientation(.landscapeLeft)
            .frame(width: 1024, height: 768)
    }
}
