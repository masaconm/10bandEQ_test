import SwiftUI
import Combine
import CoreMIDI

// MIDIEndpointRef の拡張を追加
extension MIDIEndpointRef {
    func getName() -> String? {
        var param: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(self, kMIDIPropertyName, &param) == noErr {
            return param?.takeRetainedValue() as String?
        }
        return nil
    }
}

class MIDIMappingViewModel: ObservableObject {
    @Published var mappings: [MIDIMapping] = []
    
    // 期待するパラメーター名（10バンド EQ ＋ GAIN）
    private let expectedMappingNames: [String] = [
        "EQ 32Hz", "EQ 64Hz", "EQ 125Hz", "EQ 250Hz", "EQ 500Hz",
        "EQ 1kHz", "EQ 2kHz", "EQ 4kHz", "EQ 8kHz", "EQ 16kHz",
        "GAIN"
    ]
    
    // 定期監視用のタイマー
    private var midiTimer: AnyCancellable?
    
    init() {
        // 初期状態として、必要な mapping を追加
        populateDefaultMappings()
        // タイマーで MIDI 接続状態を監視
        midiTimer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMappingsBasedOnMIDIConnection()
            }
    }
    
    /// 必要な mapping を未割当 (-1) 状態で追加
    private func populateDefaultMappings() {
        for expected in expectedMappingNames {
            if !mappings.contains(where: { $0.parameterName == expected }) {
                mappings.append(MIDIMapping(parameterName: expected, midiCC: -1))
            }
        }
        sortMappings()
    }
    
    /// expectedMappingNames の順に並び替え
    private func sortMappings() {
        mappings.sort { first, second in
            let firstIndex = expectedMappingNames.firstIndex(of: first.parameterName) ?? 0
            let secondIndex = expectedMappingNames.firstIndex(of: second.parameterName) ?? 0
            return firstIndex < secondIndex
        }
    }
    
    /// MIDI 接続状態をチェックし、KORG nanoKONTROL が接続されていれば preset を適用する
    func updateMappingsBasedOnMIDIConnection() {
        if MIDIGetNumberOfSources() > 0 {
            let source = MIDIGetSource(0)
            if let controllerName = source.getName(), controllerName.contains("KORG nanoKONTROL") {
                // もし EQ 32Hz の mapping が未割当 (-1) なら、preset を適用
                if let eq32Mapping = mappings.first(where: { $0.parameterName == "EQ 32Hz" }),
                   eq32Mapping.midiCC == -1 {
                    
                    // preset 適用：例として 3 つの mapping を設定
                    let presetMappings: [MIDIMapping] = [
                        MIDIMapping(parameterName: "EQ 32Hz", midiCC: 10),
                        MIDIMapping(parameterName: "EQ 64Hz", midiCC: 11),
                        MIDIMapping(parameterName: "GAIN",    midiCC: 12)
                    ]
                    
                    // preset に含まれる mapping を上書きし、他の mapping はそのまま残す
                    mappings = presetMappings + mappings.filter { mapping in
                        !["EQ 32Hz", "EQ 64Hz", "GAIN"].contains(mapping.parameterName)
                    }
                    sortMappings()
                }
            }
        }
    }
    
    deinit {
        midiTimer?.cancel()
    }
}

