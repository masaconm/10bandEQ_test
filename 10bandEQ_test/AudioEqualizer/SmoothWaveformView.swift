// 20250413　波形overview追加更新

import SwiftUI

// 波形のスタイル：両方とも塗りつぶし表示に統一
enum WaveformStyle {
    case filled     // メイン波形表示
    case overview   // 概要表示（下部）
}

// 環境変数で波形スタイルを切り替え可能に
struct WaveformStyleKey: EnvironmentKey {
    static let defaultValue: WaveformStyle = .filled
}

extension EnvironmentValues {
    var waveformStyle: WaveformStyle {
        get { self[WaveformStyleKey.self] }
        set { self[WaveformStyleKey.self] = newValue }
    }
}

// 波形ビュー本体
struct SmoothWaveformView: View {
    let sampleBuffer: SampleBuffer
    let playbackProgress: Double
    let zoomScale: CGFloat
<<<<<<< HEAD
=======
   
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    
    @Environment(\.waveformStyle) var waveformStyle
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            let samples = sampleBuffer.samples.map { CGFloat($0) }
            let count = max(samples.count, 1)
            
            let displaySamples: [CGFloat] = {
                switch waveformStyle {
                case .filled:
                    return samples
                case .overview:
                    let targetCount = min(1000, count)
                    guard count > targetCount else { return samples }
                    let step = max(count / targetCount, 1)
                    return stride(from: 0, to: count, by: step).map { samples[$0] }
                }
            }()
            
            let resampledCount = max(displaySamples.count, 2)
            let effectiveStep = width / CGFloat(resampledCount - 1)
            
            let topPoints = displaySamples.enumerated().map { (index, sample) in
                CGPoint(x: CGFloat(index) * effectiveStep, y: height / 2 - sample * (height / 2))
            }
            let bottomPoints = displaySamples.enumerated().map { (index, sample) in
                CGPoint(x: CGFloat(index) * effectiveStep, y: height / 2 + sample * (height / 2))
            }
            
            Canvas { context, _ in
                // スタイルにかかわらず共通の色（不透明シアン）
                let waveformColor: Color = Color(hex: "#00FFFF")
                
                var path = Path()
                path.move(to: CGPoint(x: 0, y: height / 2))
                for pt in topPoints { path.addLine(to: pt) }
                for pt in bottomPoints.reversed() { path.addLine(to: pt) }
                path.closeSubpath()
                
                context.fill(path, with: .color(waveformColor))
            }
        }
    }
}
