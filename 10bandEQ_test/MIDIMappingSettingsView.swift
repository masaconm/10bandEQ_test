import SwiftUI
import CoreMIDI

struct MIDIMappingSettingsView: View {
    // AudioEngineViewModel の midiMappings を Binding で受け取る
    @Binding var mappings: [MIDIMapping]
    @Environment(\.presentationMode) var presentationMode

    // 期待するパラメーター名（10バンド EQ ＋ GAIN）
    let expectedMappingNames: [String] = [
        "EQ 32Hz", "EQ 64Hz", "EQ 125Hz", "EQ 250Hz", "EQ 500Hz",
        "EQ 1kHz", "EQ 2kHz", "EQ 4kHz", "EQ 8kHz", "EQ 16kHz",
        "GAIN"
    ]
    
    // 編集用状態（アラート表示用）
    @State private var editingMapping: MIDIMapping? = nil
    @State private var newCCString: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach($mappings) { $mapping in
                    HStack {
                        // パラメーター名表示
                        Text(mapping.parameterName)
                        Spacer()
                        // 割り当てられている場合は CC 番号、そうでなければ「未割当」
                        if mapping.midiCC >= 0 {
                            Text("CC \(mapping.midiCC)")
                                .foregroundColor(.blue)
                        } else {
                            Text("未割当")
                                .foregroundColor(.gray)
                        }
                        // 解除ボタン（タップで未割当にする）
                        Button(action: {
                            if let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
                                mappings[index].midiCC = -1
                            }
                        }) {
                            Text("解除")
                                .foregroundColor(.red)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // タップでアラート表示用の編集対象に設定
                        editingMapping = mapping
                        newCCString = mapping.midiCC >= 0 ? "\(mapping.midiCC)" : ""
                    }
                }
                .onMove(perform: moveMapping)
            }
            .navigationTitle("MIDI Mapping Settings")
            .navigationBarItems(
                leading: EditButton(),
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            // 不足しているパラメーターがあれば onAppear で追加
            .onAppear {
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
            // 編集用アラート
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
    }
    
    func moveMapping(from source: IndexSet, to destination: Int) {
        mappings.move(fromOffsets: source, toOffset: destination)
    }
}

