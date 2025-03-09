//
//  SettingsView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/09.
//

import SwiftUI

/// SettingsView: A full-screen settings screen that is presented by a single tap on the Settings button.
/// It displays a segmented picker at the top to switch between Audio, MIDI, and Language settings.
struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case audio = "Audio Settings"
        case midi = "MIDI Settings"
        case language = "Language"
        var id: Self { self }
    }
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: Tab = .audio

    var body: some View {
        VStack {
            // セグメントピッカーでタブを切り替え
            Picker("Settings", selection: $selectedTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // 選択されたタブに応じた内容を表示
            Group {
                switch selectedTab {
                case .audio:
                    AudioInterfaceSettingsView()
                case .midi:
                    // 実際は ViewModel から Binding を渡すようにしてください
                    MIDIMappingSettingsView(mappings: .constant([]))
                case .language:
                    LanguageSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 閉じるボタン
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
