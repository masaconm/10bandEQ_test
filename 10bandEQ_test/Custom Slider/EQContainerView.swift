//EQContainerView.swift

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct EQContainerView: View {
    @State private var selectedBands: Set<String> = []
    @ObservedObject var viewModel: AudioEngineViewModel
    @State private var isRecording = false // 録音状態をトグルで管理



    // ViewModelから取得したEQバンド配列
    private var eqBands: [Float] {
        viewModel.eqBandsFrequencies
    }

    var body: some View {
        GeometryReader { geo in
            // レイアウトサイズ計算
            let totalWidth = geo.size.width
            let containerHeight = geo.size.height
            let sliderHeight = containerHeight * 0.66
            let labelHeight = containerHeight * 0.34
            let eqAreaWidth = totalWidth * 0.6
            let gainSliderWidth = totalWidth * 0.1

            // HStackで左右にBOXを分離
// MARK: - 録音 / 再生 ボタン列
            HStack(spacing: 10) {
                VStack {
                    Spacer()

                    // MARK: - Default + HI / MID / LOW ボタン群（縦に並べる）
                    VStack(spacing: 8) {
                        // ✅ 追加：Default ボタン（上部）
                        Button(action: {
                            selectedBands.removeAll()
                            viewModel.resetEQToDefault()
                        }) {
                            Text("Default")
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 70, height: 30)
                                .background(Color(hex: "#2a2e2f"))
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(hex: "#202425"), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())

                        // ✅ 既存の HI / MID / LOW ボタン群
                        ForEach(["HI", "MID", "LOW"], id: \.self) { name in
                            let isSelected = selectedBands.contains(name)

                            Button(action: {
                                if isSelected {
                                    selectedBands.remove(name)
                                    // OFFにする場合 viewModel.resetEQToDefault() も可
                                } else {
                                    selectedBands = [name]
                                    viewModel.applyBandOnly(name)
                                }
                            }) {
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(isSelected ? Color(hex: "#d82c19") : Color(hex: "#8a8b8d"))
                                    .frame(width: 70, height: 30)
                                    .background(Color(hex: "#2a2e2f"))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? Color(hex: "#d82c19").opacity(0.6) : .clear, radius: 6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 16)



                    // MARK: - 録音・再生ボタン
                    Spacer()
                    VStack(spacing: 16) {
                        // 録音ボタン
                        Button(action: {
                            isRecording.toggle()
                            print("録音ボタンがタップされました")
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#2a2e2f"))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                Image(systemName: "record.circle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(isRecording ? Color(hex: "#d82c19") : Color(hex: "#818284"))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 再生ボタン
                        Button(action: {
                            viewModel.togglePlayback()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(viewModel.playerNode.isPlaying ? Color(hex: "#212224") : Color(hex: "#292b2a"))
                                    .frame(width: 70, height: 70)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                Image(systemName: "play.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(viewModel.playerNode.isPlaying ? Color(hex: "#d82c19") : Color(hex: "#8a8b8d"))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
                .frame(width: 100, height: containerHeight)
                .background(Color(hex: "#19191b"))
                .cornerRadius(8)

                // MARK: - EQ + GAIN + LEVEL 列
                HStack(spacing: 10) {
                    eqSlidersView(sliderHeight: sliderHeight, labelHeight: labelHeight, eqAreaWidth: eqAreaWidth, containerHeight: containerHeight)

                    gainSliderView(sliderHeight: sliderHeight, labelHeight: labelHeight, gainSliderWidth: gainSliderWidth)

                    levelMeterView(sliderHeight: sliderHeight, labelHeight: labelHeight)
                }
                .padding()
                .frame(height: containerHeight)
                .background(Color(hex: "#19191b"))
                .cornerRadius(8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 20)
        }
        .background(Color.black.opacity(0.2))
    }

    // MARK: - 共通スライダー構成
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

    // MARK: - EQスライダー群
    private func eqSlidersView(sliderHeight: CGFloat, labelHeight: CGFloat, eqAreaWidth: CGFloat, containerHeight: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(eqBands.indices, id: \.self) { index in
                let sliderBinding = Binding<Float>(
                    get: { viewModel.eqValues[index] },
                    set: { newValue in viewModel.updateEQ(at: index, value: newValue) }
                )

                VStack(spacing: 2) {
                    defaultEQSlider(value: sliderBinding, range: -40...40)
                        .frame(width: 20, height: sliderHeight)

                    Text(eqBands[index] >= 1000 ?
                         "\(eqBands[index]/1000, specifier: "%.1f") kHz" :
                         "\(Int(eqBands[index])) Hz")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .frame(height: labelHeight / 6)

                    Text(String(format: "%+05.1f dB", viewModel.eqValues[index]))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 60, height: labelHeight / 4)
                }
                .frame(height: containerHeight)
            }
        }
        .frame(width: eqAreaWidth)
    }

    // MARK: - GAINスライダー
    private func gainSliderView(sliderHeight: CGFloat, labelHeight: CGFloat, gainSliderWidth: CGFloat) -> some View {
        VStack(spacing: 2) {
            defaultEQSlider(value: $viewModel.gain, range: 0...2)
                .frame(width: 20, height: sliderHeight)

            Text("Gain")
                .font(.system(size: 8))
                .foregroundColor(.white)
                .frame(height: labelHeight / 6)

            Text(String(format: "%.2f", viewModel.gain))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 50, height: labelHeight / 4)
        }
        .frame(width: gainSliderWidth)
    }

    // MARK: - レベルメーター
    private func levelMeterView(sliderHeight: CGFloat, labelHeight: CGFloat) -> some View {
        VStack(spacing: 2) {
            LevelMeterViewSwiftUI(level: viewModel.level)
                .frame(width: 20, height: sliderHeight)

            VStack(spacing: 2) {
                Text("Current Loudness")
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                Text(String(format: "%.2f dB", viewModel.level))
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 60)
        }
    }
}

