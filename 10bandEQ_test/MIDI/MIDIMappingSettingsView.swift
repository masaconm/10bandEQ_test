import SwiftUI
import CoreMIDI
import Combine

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

class MIDIMessagePublisher: ObservableObject {
    static let shared = MIDIMessagePublisher()
    let subject = PassthroughSubject<[UInt8], Never>()
    var publisher: AnyPublisher<[UInt8], Never> {
        subject.eraseToAnyPublisher()
    }
}

func extractCCFrom(_ message: [UInt8]) -> Int? {
    guard message.count >= 3 else { return nil }
    if message[0] >= 0xB0 && message[0] <= 0xBF {
        return Int(message[1])
    }
    return nil
}

struct MIDIMappingSettingsView: View {
    @Binding var mappings: [MIDIMapping]
    @Environment(\.presentationMode) var presentationMode
    
    let expectedMappingNames: [String] = [
        "EQ 32Hz", "EQ 64Hz", "EQ 125Hz", "EQ 250Hz", "EQ 500Hz",
        "EQ 1kHz", "EQ 2kHz", "EQ 4kHz", "EQ 8kHz", "EQ 16kHz",
        "GAIN"
    ]
    
    @State private var editingMapping: MIDIMapping? = nil
    @State private var candidateNewCC: Int? = nil
    @State private var showEditOptions: Bool = false
    @State private var showConfirmAlert: Bool = false
    
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
    
    func isValidControllerName(_ name: String) -> Bool {
        if name == "M4" { return false }
        return true
    }
    
    var assignedCCNumbers: Set<Int> {
        Set(mappings.compactMap { $0.midiCC >= 0 ? $0.midiCC : nil })
    }
    
    var availableCCNumbers: [Int] {
        (0...127).filter { !assignedCCNumbers.contains($0) }
    }
    
    func pickerOptions(for mapping: MIDIMapping) -> [Int] {
        var options = availableCCNumbers
        if mapping.midiCC != -1 && !options.contains(mapping.midiCC) {
            options.append(mapping.midiCC)
        }
        return options.sorted()
    }
    
    private var sortedMappings: [MIDIMapping] {
        expectedMappingNames.compactMap { name in
            mappings.first(where: { $0.parameterName == name })
        }
    }
    
    var body: some View {
        
        NavigationView {
            VStack(spacing: 0) {
                //  カスタムヘッダー
                HStack {
                    Text("MIDI Mappings")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 20)
                
                //  接続デバイス表示
                if !connectedControllers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected device:")
                            .font(.headline)
                            .foregroundColor(.white)
                        ForEach(connectedControllers, id: \.self) { controller in
                            Text(controller)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading) //  左寄せにする
                } else {
                    Text("No connected device")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading) //  こちらも左寄せ
                        .padding(.bottom, 20)
                }
                
                
                //// MIDIマッピング編集 リスト本体
                
                //  見出し行（固定表示）
                HStack {
                    Text("Name")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CC/Note")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Status")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Edit")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal)
                .background(Color(hex: "#2a2e2f"))
                //                .cornerRadius(6)
                
                // スクロール可能なリスト（2行目以降）
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(sortedMappings.enumerated()), id: \.element.id) { index, mapping in
                            HStack {
                                Text(mapping.parameterName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.white)
                                
                                Text(mapping.midiCC >= 0 ? "CC \(mapping.midiCC)" : "None")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.white)
                                
                                Text(mapping.midiCC >= 0 ? "On" : "Off")
                                    .foregroundColor(mapping.midiCC >= 0 ? .green : .gray)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Button("Edit") {
                                    editingMapping = mapping
                                    showEditOptions = true
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundColor(.white)
                            }
                            .font(.system(size: 14))
                            .padding(.vertical, 6)
                            .padding(.horizontal)
                            .background(index % 2 == 0 ? Color(hex: "#46484a") : Color(hex: "#46484a")) //  交互色
                            //                            .cornerRadius(6)
                        }
                    }
                }
                .background(Color(hex: "#393d40"))
                
                
                
                
            }
            .background(Color(hex: "#393d40"))
            .navigationBarHidden(true)
            .confirmationDialog("Select CC/Note", isPresented: $showEditOptions) {
                Button("None") {
                    candidateNewCC = -1
                    showConfirmAlert = true
                }
                if let editingMapping = editingMapping {
                    ForEach(pickerOptions(for: editingMapping), id: \.self) { cc in
                        Button("CC \(cc)") {
                            candidateNewCC = cc
                            showConfirmAlert = true
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Confirm change", isPresented: $showConfirmAlert, actions: {
                Button("OK") {
                    if let mapping = editingMapping,
                       let newCC = candidateNewCC,
                       let index = mappings.firstIndex(where: { $0.id == mapping.id }) {
                        mappings[index].midiCC = newCC
                    }
                    editingMapping = nil
                    candidateNewCC = nil
                }
                Button("Cancel", role: .cancel) {
                    editingMapping = nil
                    candidateNewCC = nil
                }
            }, message: {
                if let mapping = editingMapping, let newCC = candidateNewCC {
                    Text("Change \(mapping.parameterName)'s CC from \(mapping.midiCC >= 0 ? "CC \(mapping.midiCC)" : "None") to \(newCC == -1 ? "None" : "CC \(newCC)")?")
                }
            })
        }
    }
}
