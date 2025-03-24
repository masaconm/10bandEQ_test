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
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if !connectedControllers.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected device:")
                            .font(.headline)
                        ForEach(connectedControllers, id: \.self) { controller in
                            Text(controller)
                        }
                    }
                    .padding()
                } else {
                    Text("No connected")
                        .foregroundColor(.red)
                        .padding()
                }
                
                HStack {
                    Text("Name")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CC/Note")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Status")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Edit CC/Note")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding([.leading, .trailing, .top])
                
                List {
                    Section {
                        ForEach($mappings) { $mapping in
                            HStack {
                                Text(mapping.parameterName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Group {
                                    if mapping.midiCC >= 0 {
                                        Text("CC \(mapping.midiCC)")
                                    } else {
                                        Text("None")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Group {
                                    if mapping.midiCC >= 0 {
                                        Text("On")
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("Off")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                
                                Button("Edit") {
                                    editingMapping = mapping
                                    showEditOptions = true
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .onMove(perform: moveMapping)
                    }
                }
                .navigationTitle("MIDI Mappings")
                .confirmationDialog("Select CC/Note", isPresented: $showEditOptions, titleVisibility: .visible) {
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
            // onAppear 内の preset 適用ロジックは不要
        }
    }
    
    func moveMapping(from source: IndexSet, to destination: Int) {
        mappings.move(fromOffsets: source, toOffset: destination)
    }
}

