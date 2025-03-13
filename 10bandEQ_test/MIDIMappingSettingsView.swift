//MIDIMappingSettingsView.swift

import SwiftUI
import CoreMIDI
import Combine

// MARK: - MIDIEndpointRef Extension

extension MIDIEndpointRef {
    func getControllerFullName() -> String? {
        var manufacturerRef: Unmanaged<CFString>?
        var displayNameRef: Unmanaged<CFString>?
        let manufacturerStatus = MIDIObjectGetStringProperty(self, kMIDIPropertyManufacturer, &manufacturerRef)
        let displayNameStatus = MIDIObjectGetStringProperty(self, kMIDIPropertyDisplayName, &displayNameRef)
        
        if manufacturerStatus == noErr, displayNameStatus == noErr,
           let manufacturer = manufacturerRef?.takeUnretainedValue() as String?,
           let displayName = displayNameRef?.takeUnretainedValue() as String? {
            return "\(manufacturer) \(displayName)"
        }
        return nil
    }
}


// MARK: - MIDI Message Publisher (サンプル実装)
// 実際はMIDIManagerからMIDIメッセージを流すように実装してください
class MIDIMessagePublisher: ObservableObject {
    static let shared = MIDIMessagePublisher()
    let subject = PassthroughSubject<[UInt8], Never>()
    var publisher: AnyPublisher<[UInt8], Never> {
        subject.eraseToAnyPublisher()
    }
}

// MIDI CCメッセージからCC番号を抽出する関数
func extractCCFrom(_ message: [UInt8]) -> Int? {
    guard message.count >= 3 else { return nil }
    // Control Change メッセージ (0xB0～0xBF) の場合、2番目のバイトがCC番号
    if message[0] >= 0xB0 && message[0] <= 0xBF {
        return Int(message[1])
    }
    return nil
}

// MARK: - MIDIMappingSettingsView

struct MIDIMappingSettingsView: View {
    @Binding var mappings: [MIDIMapping]
    @Environment(\.presentationMode) var presentationMode

    // 期待するパラメーター名（10バンド EQ ＋ GAIN）
    let expectedMappingNames: [String] = [
        "EQ 32Hz", "EQ 64Hz", "EQ 125Hz", "EQ 250Hz", "EQ 500Hz",
        "EQ 1kHz", "EQ 2kHz", "EQ 4kHz", "EQ 8kHz", "EQ 16kHz",
        "GAIN"
    ]
    
    // 編集用状態（直接入力編集用アラート）
    @State private var editingMapping: MIDIMapping? = nil
    @State private var newCCString: String = ""
    
    // 接続中のMIDIコントローラー名を取得（フィルタ付き）
    var connectedControllers: [String] {
        var names: [String] = []
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let src = MIDIGetSource(i)
            if let name = src.getControllerFullName(), isValidControllerName(name) {
                names.append(name)
            }
        }
        return names
    }
    
    // 簡易フィルタ例：例えば「M4」はオーディオインターフェースとして除外
    func isValidControllerName(_ name: String) -> Bool {
        if name == "M4" { return false }
        return true
    }
    
    // 現在「手動割当」または「MIDI割当」で割当待ち中の項目のID
    @State private var waitingMappingID: UUID? = nil
    // MIDI操作による割当モードの状態
    @State private var isAssignModeActive: Bool = false
    @State private var midiCancellable: AnyCancellable? = nil
    
    // 現在割り当て中の CC 番号のセット（UI表示用）
    var assignedCCNumbers: Set<Int> {
        Set(mappings.compactMap { $0.midiCC >= 0 ? $0.midiCC : nil })
    }
    
    // 0～127 の中で、他で使われていない番号一覧（UI表示用）
    var availableCCNumbers: [Int] {
        (0...127).filter { !assignedCCNumbers.contains($0) }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // ヘッダー：接続中のMIDIコントローラー一覧
                if !connectedControllers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("接続中のMIDIコントローラー:")
                            .font(.headline)
                        ForEach(connectedControllers, id: \.self) { controller in
                            Text(controller)
                        }
                    }
                    .padding()
                } else {
                    Text("MIDIコントローラーが接続されていません")
                        .foregroundColor(.red)
                        .padding()
                }
                
                List {
                    // マッピング項目の一覧
                    Section(header: Text("マッピング")) {
                        ForEach($mappings) { $mapping in
                            HStack {
                                Text(mapping.parameterName)
                                Spacer()
                                if mapping.midiCC >= 0 {
                                    Text("CC \(mapping.midiCC) (割り当て中)")
                                        .foregroundColor(.blue)
                                    Button("解除") {
                                        if let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
                                            mappings[index].midiCC = -1
                                        }
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                } else {
                                    Text("未割当")
                                        .foregroundColor(.gray)
                                    // 手動割当ボタン
                                    Button("手動割当") {
                                        waitingMappingID = mapping.id
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    // MIDI割当ボタン
                                    Button("MIDI割当") {
                                        waitingMappingID = mapping.id
                                        isAssignModeActive = true
                                        startListeningForMIDI()
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            .contentShape(Rectangle())
                            // 割当待ち中の項目は背景色でハイライト
                            .background((waitingMappingID == mapping.id) ? Color.yellow.opacity(0.3) : Color.clear)
                            .onTapGesture {
                                // タップで直接編集用のアラートを表示（任意実装）
                                editingMapping = mapping
                                newCCString = mapping.midiCC >= 0 ? "\(mapping.midiCC)" : ""
                            }
                        }
                        .onMove(perform: moveMapping)
                    }
                    
                    // 手動割当用：空きのあるCC番号一覧（常時表示）
                    if !availableCCNumbers.isEmpty {
                        Section(header: Text("空きのあるCCノート番号（手動選択）")) {
                            ForEach(availableCCNumbers, id: \.self) { cc in
                                Button("CC \(cc)") {
                                    if let id = waitingMappingID,
                                       let index = mappings.firstIndex(where: { $0.id == id }) {
                                        mappings[index].midiCC = cc
                                        waitingMappingID = nil
                                    }
                                }
                            }
                        }
                    }
                    
                    // MIDI操作による割当モードの状態表示と制御
                    Section(header: Text("MIDI操作による割当モード")) {
                        HStack {
                            Text(isAssignModeActive ? "MIDI割当モード中：コントローラー操作してください" : "MIDI割当モードOFF")
                            Spacer()
                            Button(isAssignModeActive ? "モード終了" : "モード開始") {
                                isAssignModeActive.toggle()
                                if isAssignModeActive {
                                    startListeningForMIDI()
                                } else {
                                    stopListeningForMIDI()
                                }
                            }
                        }
                    }
                }
                .navigationTitle("MIDI Mapping Settings")
                .alert(item: $editingMapping) { mapping in
                    Alert(
                        title: Text("Change MIDI CC for \(mapping.parameterName)"),
                        message: Text("Current value: \(newCCString)\n(Enter new value in a custom UI)"),
                        primaryButton: .default(Text("OK"), action: {
                            if let newCC = Int(newCCString),
                               newCC >= 0, newCC <= 127,
                               let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
                                mappings[index].midiCC = newCC
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                }
            }
            .onAppear {
                // 期待されるパラメーターが不足していれば追加
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
    }
    
    // MARK: - Helper Functions
    
    // 並び替え処理
    func moveMapping(from source: IndexSet, to destination: Int) {
        mappings.move(fromOffsets: source, toOffset: destination)
    }
    
    // MIDI割当モード開始：MIDIメッセージ受信を開始
    func startListeningForMIDI() {
        midiCancellable = MIDIMessagePublisher.shared.publisher.sink { message in
            if let cc = extractCCFrom(message),
               let id = waitingMappingID,
               let index = mappings.firstIndex(where: { $0.id == id }) {
                mappings[index].midiCC = cc
                waitingMappingID = nil
                isAssignModeActive = false
                stopListeningForMIDI()
            }
        }
    }
    
    // MIDI割当モード終了：MIDIメッセージ受信の購読を解除
    func stopListeningForMIDI() {
        midiCancellable?.cancel()
        midiCancellable = nil
    }
}

