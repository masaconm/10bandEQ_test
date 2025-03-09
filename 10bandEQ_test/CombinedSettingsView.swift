import SwiftUI

/// CombinedSettingsView: A unified settings screen with a left sidebar menu.
/// Uses a List (with onTapGesture) for the sidebar so that tapping a row immediately
/// switches the detail content.
struct CombinedSettingsView: View {
    enum SettingsTab: String, CaseIterable, Identifiable {
        case audio = "Audio Settings"
        case midi = "MIDI Settings"
        case language = "Language"
        
        var id: Self { self }
    }
    
    @State private var selectedTab: SettingsTab = .audio
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                ForEach(SettingsTab.allCases) { tab in
                    HStack {
                        Text(tab.rawValue)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTab = tab
                    }
                    .background(selectedTab == tab ? Color(UIColor.darkGray) : Color.clear)

                }
            }
            .listStyle(SidebarListStyle())
            .frame(width: 200)
            .background(Color(UIColor.systemGray6))
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
            
            // Detail Area
            Group {
                switch selectedTab {
                case .audio:
                    AudioInterfaceSettingsView()
                case .midi:
                    MIDIMappingSettingsView(mappings: .constant([])) // Binding を適宜設定
                case .language:
                    LanguageSettingsView()
                }
            }
            .navigationTitle(selectedTab.rawValue)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct CombinedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedSettingsView()
    }
}

