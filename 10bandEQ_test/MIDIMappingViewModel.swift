
import SwiftUI
import Combine

class MIDIMappingViewModel: ObservableObject {
    @Published var mappings: [MIDIMapping] = []
    
    // 期待するパラメーター名（10バンド EQ ＋ GAIN）
    private let expectedMappingNames: [String] = [
        "EQ 32Hz", "EQ 64Hz", "EQ 125Hz", "EQ 250Hz", "EQ 500Hz",
        "EQ 1kHz", "EQ 2kHz", "EQ 4kHz", "EQ 8kHz", "EQ 16kHz",
        "GAIN"
    ]
    
    init() {
        // 必要なパラメーターが不足していれば追加
        for expected in expectedMappingNames {
            if !mappings.contains(where: { $0.parameterName == expected }) {
                mappings.append(MIDIMapping(parameterName: expected, midiCC: -1))
            }
        }
        // 並び順を期待する順に整える
        mappings.sort { first, second in
            let firstIndex = expectedMappingNames.firstIndex(of: first.parameterName) ?? 0
            let secondIndex = expectedMappingNames.firstIndex(of: second.parameterName) ?? 0
            return firstIndex < secondIndex
        }
    }
}
