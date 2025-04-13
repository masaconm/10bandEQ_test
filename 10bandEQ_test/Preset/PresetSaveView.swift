import SwiftUI
import AVFoundation

struct PresetSaveView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: AudioEngineViewModel
    @State private var presetName: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                
                //  カスタムヘッダー：左寄せタイトル＋右にキャンセルボタン
                HStack {
                    Text("Save Preset")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // MARK: - PRESET NAME 入力欄
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preset Name")
                        .foregroundColor(Color(hex: "#ccffff"))
                        .font(.subheadline)
                    TextField("Enter name", text: $presetName)
                        .foregroundColor(Color(hex: "#393d40"))
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(6)
                }
                .padding(.horizontal)
                
                // MARK: - SAVEボタン
                Button(action: {
                    if !presetName.isEmpty {
                        let filterTypes = viewModel.eqNode.bands.map { $0.filterType }
                        let newPreset = EQPreset(
                            name: presetName,
                            eqValues: viewModel.eqValues,
                            filterTypes: filterTypes
                        )
                        viewModel.userPresets.append(newPreset)
                        viewModel.saveUserPresetsToDefaults()
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("SAVE")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundColor(.black)
                        .font(.system(size: 16, weight: .bold))
                        .padding(.vertical, 8)
                        .background(Color(hex: "#ccffff"))
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal)
                
                // MARK: - CURRENT EQ SETTINGS（スクロール可能）
                Text("Current EQ Settings")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.top, 10)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(0..<viewModel.eqBandsFrequencies.count, id: \.self) { index in
                            HStack {
                                Text("\(Int(viewModel.eqBandsFrequencies[index])) Hz")
                                    .frame(width: 60, alignment: .leading)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                
                                Text(String(format: "%+05.1f dB", viewModel.eqValues[index]))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(viewModel.eqNode.bands[index].filterType.displayName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#393d40"))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 10)
            }
            .background(Color(hex: "#393d40"))
            .navigationBarHidden(true) //  デフォルトのナビゲーションバーを非表示に
        }
    }
}
