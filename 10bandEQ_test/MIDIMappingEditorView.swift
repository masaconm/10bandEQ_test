//
//  MIDIMappingEditorView.swift
//  10bandEQ_test
//
//  改修版: 接続されたMIDIコントローラー名の表示と、KORG nanoKONTROL接続時にプリセットを適用
//

import SwiftUI
import CoreMIDI

// CoreMIDIのMIDIEndpointRefに対して、デバイス名を取得する拡張を追加
extension MIDIEndpointRef {
    func getName() -> String? {
        var param: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(self, kMIDIPropertyName, &param) == noErr {
            return param?.takeRetainedValue() as String?
        }
        return nil
    }
}

/// MIDI マッピングの一覧を表形式で表示し、各行をタップすると詳細編集画面へ遷移するビュー
struct MIDIMappingEditorView: View {
    @Binding var mappings: [MIDIMapping]
    
    // 全ての MIDI CC 番号（0～127）の一覧
    let allCCNumbers = Array(0...127)
    
    /// すでに割り当てられている CC 番号（-1は未割当の場合として除外）
    var assignedCCNumbers: Set<Int> {
        Set(mappings.map { $0.midiCC }.filter { $0 >= 0 })
    }
    
    /// 空いている（未割当の） CC 番号
    var availableCCNumbers: [Int] {
        allCCNumbers.filter { !assignedCCNumbers.contains($0) }
    }
    
    /// 接続されている MIDI ソースがあるかをチェック
    var midiConnected: Bool {
        MIDIGetNumberOfSources() > 0
    }
    
    /// 最初の接続MIDIソースからデバイス名を取得
    var midiControllerName: String? {
        guard midiConnected else { return nil }
        let source = MIDIGetSource(0)
        return source.getName() // ここを修正
    }


    
    /// KORG nanoKONTROL用のプリセットマッピング（必要に応じて調整してください）
    var korgPresetMappings: [MIDIMapping] {
        return [
            MIDIMapping(parameterName: "EQ 32Hz", midiCC: 10),
            MIDIMapping(parameterName: "EQ 64Hz", midiCC: 11),
            MIDIMapping(parameterName: "GAIN",    midiCC: 12)
            // 他のパラメーターも必要に応じて追加
        ]
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 接続されたMIDIコントローラー名の表示
                if let controllerName = midiControllerName {
                    Text("接続されたMIDIコントローラー: \(controllerName)")
                        .font(.headline)
                        .padding(.top)
                }
                
                if !midiConnected {
                    // MIDI コントローラーが接続されていない場合の表示
                    VStack {
                        Text("MIDI コントローラーが接続されていません")
                            .foregroundColor(.red)
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                } else {
                    // MIDI コントローラーが接続されている場合は、マッピング一覧を表示
                    List {
                        Section(header: Text("マッピング済み")) {
                            ForEach($mappings) { $mapping in
                                NavigationLink(destination: MIDIMappingDetailEditor(mapping: $mapping, availableCCNumbers: availableCCNumbers)) {
                                    HStack {
                                        Text(mapping.parameterName)
                                        Spacer()
                                        if mapping.midiCC >= 0 {
                                            Text("CC \(mapping.midiCC)")
                                                .foregroundColor(.blue)
                                        } else {
                                            Text("未割当")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        Section(header: Text("空いている CC 番号")) {
                            ForEach(availableCCNumbers, id: \.self) { cc in
                                Text("CC \(cc)")
                            }
                        }
                    }
                }
            }
            .navigationTitle("MIDI マッピング設定")
            .onAppear {
                // KORG nanoKONTROLが接続されている場合、プリセットマッピングを自動適用
                if let controllerName = midiControllerName, controllerName == "KORG nanoKONTROL" {
                    // ※ここでは簡単のためプリセットに置き換えていますが、
                    // ユーザーの変更を残す場合は条件やタイミングを調整してください。
                    mappings = korgPresetMappings
                }
            }
        }
    }
}

/// 詳細編集画面：選択したパラメーターの MIDI CC 番号を Picker で変更する
struct MIDIMappingDetailEditor: View {
    @Binding var mapping: MIDIMapping
    let availableCCNumbers: [Int]
    
    // 編集用のローカル状態（Picker の選択値）
    @State private var selectedCC: Int = -1
    
    var body: some View {
        Form {
            Section(header: Text(mapping.parameterName)) {
                Picker("MIDI CC 番号", selection: $selectedCC) {
                    Text("未割当").tag(-1)
                    ForEach(availableCCNumbers, id: \.self) { cc in
                        Text("CC \(cc)").tag(cc)
                    }
                    // もし現在の値が空きリストに含まれていなければ表示
                    if selectedCC != -1 && !availableCCNumbers.contains(selectedCC) {
                        Text("CC \(selectedCC)").tag(selectedCC)
                    }
                }
                .pickerStyle(WheelPickerStyle())
            }
        }
        .navigationTitle("MIDI 設定")
        .onAppear {
            selectedCC = mapping.midiCC
        }
        .onDisappear {
            mapping.midiCC = selectedCC
        }
    }
}

