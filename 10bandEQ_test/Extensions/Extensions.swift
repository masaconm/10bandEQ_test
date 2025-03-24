//
// Extensions.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/24.
//

// MARK: - filterType 表示用拡張

    import AVFoundation

    extension AVAudioUnitEQFilterType {
        static var allFilterTypes: [AVAudioUnitEQFilterType] {
            return [
                .parametric,
                .lowPass,
                .highPass,
                .resonantLowPass,
                .resonantHighPass,
                .bandPass,
                .bandStop,
                .lowShelf,
                .highShelf,
                .resonantLowShelf,
                .resonantHighShelf
            ]
        }

        var displayName: String {
            switch self {
            case .parametric: return "Parametric"
            case .lowPass: return "Low Pass"
            case .highPass: return "High Pass"
            case .resonantLowPass: return "Resonant Low Pass"
            case .resonantHighPass: return "Resonant High Pass"
            case .bandPass: return "Band Pass"
            case .bandStop: return "Band Stop"
            case .lowShelf: return "Low Shelf"
            case .highShelf: return "High Shelf"
            case .resonantLowShelf: return "Resonant Low Shelf"
            case .resonantHighShelf: return "Resonant High Shelf"
            @unknown default:
                return "Unknown"
            }
        }
    }




