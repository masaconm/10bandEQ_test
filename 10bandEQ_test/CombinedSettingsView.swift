//CombinedSettingsView.swift

import SwiftUI

struct CombinedSettingsView: View {
    enum SettingsTab: String, CaseIterable, Identifiable {
        case audio = "Audio Settings"
//        case midi = "MIDI Settings"
        case language = "Language"
        
        var id: Self { self }
    }
    
    @State private var selectedTab: SettingsTab = .audio
    @Environment(\.presentationMode) var presentationMode
    
    // MIDIMappingEditorView 用の ViewModel
    @StateObject private var midiMappingVM = MIDIMappingViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Select Tab", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Group {
                    switch selectedTab {
                    case .audio:
                        AudioInterfaceSettingsView()
//                    case .midi:
//                        // MIDIMappingEditorView の内容をそのまま表示
//                        MIDIMappingSettingsView(mappings: $midiMappingVM.mappings)
                    case .language:
                        LanguageSettingsView()
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "xmark")
            })
        }
    }
}

struct CombinedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedSettingsView()
    }
}
