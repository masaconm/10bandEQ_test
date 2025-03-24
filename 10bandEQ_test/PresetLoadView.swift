//
//  PresetLoadView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/24.
//

import SwiftUI
import AVFoundation

struct PresetLoadView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // MARK: - タイトル + キャンセルボタン
                HStack {
                    Text("Load Preset")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 16) // 余白を追加
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)

//                // MARK: - Default Presets（固定）
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Default Presets")
//                        .font(.subheadline)
//                        .foregroundColor(.white)
//
//                    ForEach(viewModel.defaultPresets) { preset in
//                        Button(action: {
//                            viewModel.applyPresetWithBypass(preset)
//                            presentationMode.wrappedValue.dismiss()
//                        }) {
//                            Text(preset.name)
//                                .font(.system(size: 14))
//                                .foregroundColor(.white)
//                                .padding(8)
//                                .frame(maxWidth: .infinity, alignment: .leading)
//                                .background(Color(hex: "#2a2e2f"))
//                                .cornerRadius(6)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                    }
//                }
//                .padding(.horizontal)

                // MARK: - User Presets（スクロール）
                Text("User Presets")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.top, 10)
                    .padding(.horizontal)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.userPresets) { preset in
                            HStack {
                                // プリセット名
                                Button(action: {
                                    viewModel.applyPresetWithBypass(preset)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    Text(preset.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // 削除ボタン
                                Button(action: {
                                    viewModel.removePreset(named: preset.name)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .frame(width: 30, height: 30)
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal)
                            .background(Color(hex: "#393d40"))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 10)
            }
            .background(Color(hex: "#393d40"))
        }
    }
}
