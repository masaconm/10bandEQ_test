import SwiftUI

struct MIDIMappingSettingsView: View {
    // 別ファイルで定義した MIDIMapping 型を利用（MIDIMapping.swift）
    @Binding var mappings: [MIDIMapping]
    @Environment(\.presentationMode) var presentationMode
    
    // 編集対象のマッピングと新たに入力する MIDI CC 番号用文字列
    @State private var editingMapping: MIDIMapping? = nil
    @State private var newCCString: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(mappings) { mapping in
                    HStack {
                        Text(mapping.parameterName)
                        Spacer()
                        Text("CC \(mapping.midiCC)")
                            .foregroundColor(.blue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // タップ時に編集対象として設定し、現在の MIDI CC 番号を文字列化
                        editingMapping = mapping
                        newCCString = "\(mapping.midiCC)"
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
            // SwiftUI の Alert では直接 TextField は使えないため、
            // ここでは現在の MIDI CC 番号を表示するだけのシンプルな例
            .alert(item: $editingMapping) { mapping in
                Alert(
                    title: Text("Change MIDI CC for \(mapping.parameterName)"),
                    message: Text("Current value: \(newCCString)\n(Enter new value in a custom UI)"),
                    primaryButton: .default(Text("OK"), action: {
                        if let newCC = Int(newCCString), newCC >= 0, newCC <= 127,
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

