//
//  PresetLoadView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/24.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

// MARK: - PresetLoadView
/// ユーザーが保存した EQ プリセットを読み込むための画面
struct PresetLoadView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Default Presets")) {
                    ForEach(viewModel.defaultPresets) { preset in
                        Button(action: {
                            viewModel.applyPresetWithBypass(preset)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(preset.name)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Section(header: Text("User Presets")) {
                    ForEach(viewModel.userPresets) { preset in
                        HStack {
                            Button(action: {
                                viewModel.applyPresetWithBypass(preset)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                viewModel.removePreset(named: preset.name)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 44, height: 44)
                        }
                    }
                }
            }
            .navigationTitle("Load Preset")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
