////EQContainerView.swift
//
import SwiftUI
import AVFoundation

struct EQContainerView: View {
    @State private var selectedBands: Set<String> = []
    @ObservedObject var viewModel: AudioEngineViewModel
    @Binding var activeSheet: ActiveSheet?
    @State private var isRecording = false

    private var eqBands: [Float] {
        viewModel.eqBandsFrequencies
    }

    var body: some View {
        GeometryReader { geo in
            let contentHeight = geo.size.height * 0.8

            VStack(spacing: 10) {
                // MARK: - EQ & ボタン列（3列構成）
                HStack(spacing: 10) {

                    // MARK: 左：操作ボタン列
                    VStack(spacing: 16) {
                        // HI / MID / LOW
                        VStack(spacing: 8) {
                            ForEach(["HI", "MID", "LOW"], id: \.self) { name in
                                let isSelected = selectedBands.contains(name)
                                Button(action: {
                                    if isSelected {
                                        selectedBands.remove(name)
                                    } else {
                                        selectedBands = [name]
                                        viewModel.applyBandOnly(name)
                                    }
                                }) {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(isSelected ? Color(hex: "#d82c19") : Color(hex: "#8a8b8d"))
                                        .frame(width: 60, height: 60)
                                        .background(Color(hex: "#2a2e2f"))
                                        .cornerRadius(4)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#202425"), lineWidth: 1))
                                        .shadow(color: isSelected ? Color(hex: "#d82c19").opacity(0.6) : .clear, radius: 6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        // Default
                        Button(action: {
                            selectedBands.removeAll()
                            viewModel.resetEQToDefault()
                        }) {
                            Text("Default")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(hex: "#2a2e2f"))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#202425"), lineWidth: 1))
                        }


                        // 録音・再生
                        VStack(spacing: 16) {
                            Button(action: { isRecording.toggle() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "#2a2e2f"))
                                        .frame(width: 60, height: 60)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#202425"), lineWidth: 1))
                                    Image(systemName: "record.circle")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(isRecording ? Color(hex: "#d82c19") : Color(hex: "#818284"))
                                }
                            }

                            Button(action: {
                                viewModel.togglePlayback()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(viewModel.playerNode.isPlaying ? Color(hex: "#212224") : Color(hex: "#292b2a"))
                                        .frame(width: 60, height: 60)
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#202425"), lineWidth: 1))
                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(viewModel.playerNode.isPlaying ? Color(hex: "#d82c19") : Color(hex: "#8a8b8d"))
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(width: 100, height: contentHeight, alignment: .top)
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)

                    // MARK: 中央：EQ + GAIN + LEVEL
                    HStack(alignment: .top, spacing: 24) {
                        eqSlidersView(
                            sliderHeight: contentHeight * 0.66,
                            labelHeight: contentHeight * 0.2,
                            eqAreaWidth: geo.size.width * 0.5,
                            containerHeight: contentHeight
                        )
                        gainSliderView(
                            sliderHeight: contentHeight * 0.66,
                            labelHeight: contentHeight * 0.2,
                            gainSliderWidth: 40
                        )
                        levelMeterView(
                            sliderHeight: contentHeight * 0.66,
                            labelHeight: contentHeight * 0.2
                        )
                    }
                    .padding(30)
                    .frame(height: contentHeight)
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)

                    // MARK: 右：Save / Load Preset カラム
                    VStack(spacing: 16) {
                        Button {
                            activeSheet = .savePreset
                        } label: {
                            Text("Save Preset")
                                .frame(width: 100, height: 40)
                        }
                        .customBottomButton()

                        Button {
                            activeSheet = .loadPreset
                        } label: {
                            Text("Load Preset")
                                .frame(width: 100, height: 40)
                        }
                        .customBottomButton()

                        Spacer()
                    }
                    .frame(width: 120, height: contentHeight, alignment: .top)
                    .padding()
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)
                }

                // MARK: 下部操作列
                HStack(spacing: 12) {
                    Button("Select Audio File") {
                        activeSheet = .picker
                    }.customBottomButton()

                    Button("Playlist") {
                        activeSheet = .playlist
                    }.customBottomButton()

                    Button("MIDI Mapping") {
                        activeSheet = .midiMapping
                    }.customBottomButton()
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .background(Color.black.opacity(0.2))
        }
    }

    // MARK: - 共通ボタンスタイル
    func customBottomButton() -> some View {
        self
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#2a2e2f"))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#202425"), lineWidth: 1))
    }

    // MARK: - 共通スライダー
    private func defaultEQSlider(value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        CustomVerticalSlider(
            value: value,
            range: range,
            thumbWidth: 40,
            thumbHeight: 20,
            trackColor: Color(hex: "#292d2e"),
            fillColor: Color(hex: "#00FFFF"),
            thumbColor: Color(hex: "#363739")
        )
        
    }

    // MARK: - 各表示View
    private func eqSlidersView(
        sliderHeight: CGFloat,
        labelHeight: CGFloat,
        eqAreaWidth: CGFloat,
        containerHeight: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<eqBands.count, id: \.self) { index in
                let sliderBinding = Binding<Float>(
                    get: { viewModel.eqValues[index] },
                    set: { newValue in viewModel.updateEQ(at: index, value: newValue) }
                )

                VStack(spacing: 4) {
                    // スライダー
                    defaultEQSlider(value: sliderBinding, range: -40...40)
                        .frame(width: 20, height: sliderHeight)

                    // 周波数ラベル
                    Text(eqBands[index] >= 1000 ?
                         "\(eqBands[index]/1000, specifier: "%.1f") kHz" :
                         "\(Int(eqBands[index])) Hz")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .frame(width: 60, height: labelHeight / 4)

                    // dBラベル
                    Text(String(format: "%+05.1f dB", viewModel.eqValues[index]))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 60, height: labelHeight / 4)

                    // フィルター選択 Menu
                    if let eqNode = viewModel.eqNode, eqNode.bands.indices.contains(index) {
                        Menu {
                            ForEach(AVAudioUnitEQFilterType.allFilterTypes, id: \.self) { type in
                                Button {
                                    eqNode.bands[index].filterType = type
                                } label: {
                                    Text(type.displayName).font(.system(size: 8))
                                }
                            }
                        } label: {
                            Text(eqNode.bands[index].filterType.displayName)
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                                .frame(width: 60, height: 20)
                                .background(Color(hex: "#2a2e2f"))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#202425"), lineWidth: 1))
                        }
                    } else {
                        Text("NONE")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.5))
                            .frame(width: 60, height: 20)
                    }
                }
//                .frame(minHeight: sliderHeight + labelHeight + 30, alignment: .top) // ✅ 高さを確保して上揃え
                .frame(alignment: .top)
            }
        }
        .frame(width: eqAreaWidth)
    }


    // MARK: - GAIN
    private func gainSliderView(sliderHeight: CGFloat, labelHeight: CGFloat, gainSliderWidth: CGFloat) -> some View {
        VStack(spacing: 0.5) {
            defaultEQSlider(value: $viewModel.gain, range: 0...2)
                .frame(width: 20, height: sliderHeight)

            Text("Gain")
                .font(.system(size: 8))
                .foregroundColor(.white)
                .frame(height: labelHeight / 6)

            Text(String(format: "%.2f", viewModel.gain))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 60, height: labelHeight / 4)
        }
        .frame(width: gainSliderWidth, height: sliderHeight + labelHeight, alignment: .top) // ✅ 揃え
    }

    // MARK: - LEVEL
    private func levelMeterView(sliderHeight: CGFloat, labelHeight: CGFloat) -> some View {
        VStack(spacing: 0.5) {
            LevelMeterViewSwiftUI(level: viewModel.level)
                .frame(width: 20, height: sliderHeight)

            VStack(spacing: 2) {
                Text("Current Loudness")
                Text(String(format: "%.2f dB", viewModel.level))
            }
            .font(.system(size: 9))
            .foregroundColor(.white)
            .frame(width: 60)
        }
        .frame(height: sliderHeight + labelHeight, alignment: .top) // ✅ 上揃え
    }

}

