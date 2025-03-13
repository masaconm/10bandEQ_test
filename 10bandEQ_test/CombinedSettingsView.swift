
import SwiftUI

struct CombinedSettingsView: View {
    enum SettingsTab: String, CaseIterable, Identifiable {
        case audio = "Audio Settings"
        case midi = "MIDI Settings"
        case language = "Language"
        
        var id: Self { self }
    }
    
    @State private var selectedTab: SettingsTab = .audio
    @Environment(\.presentationMode) var presentationMode
    
    // MIDIMappingSettingsView 用の ViewModel
    @StateObject private var midiMappingVM = MIDIMappingViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // タブ切り替え用の SegmentedPicker
                Picker("Select Tab", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 選択されたタブに応じた設定画面を表示
                Group {
                    switch selectedTab {
                    case .audio:
                        AudioInterfaceSettingsView()
                    case .midi:
                        MIDIMappingSettingsView(mappings: $midiMappingVM.mappings)
                    case .language:
                        LanguageSettingsView()
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct CombinedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedSettingsView()
    }
}
