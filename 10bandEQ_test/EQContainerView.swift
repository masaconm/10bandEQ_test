////EQContainerView.swift
//
import SwiftUI
import AVFoundation

struct EQContainerView: View {
    @State private var selectedBands: Set<String> = []
    @ObservedObject var viewModel: AudioEngineViewModel
    @Binding var activeSheet: ActiveSheet?
    @State private var isRecording = false
    @State private var isFlatButtonPressed = false
    @State private var isSaveButtonPressed = false
    @State private var isLoadButtonPressed = false
    
    private var eqBands: [Float] {
        viewModel.eqBandsFrequencies
    }

    var body: some View {
        GeometryReader { geo in
            let contentHeight = geo.size.height * 0.9

            VStack(spacing: 10) {
                // MARK: - EQ & ボタン列（3列構成）
                HStack(spacing: 10) {
                    
                    // MARK: 左：操作ボタン列
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
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(isSelected ? .black : Color(hex: "#ccffff")) // 選択中は黒文字
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isSelected ? Color(hex: "#ff0000") : Color(hex: "#292b2a"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: isSelected ? Color(hex: "#ff0000").opacity(0.8) : .clear,
                                        radius: isSelected ? 10 : 0
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        
                        // FLAT ボタン
                        Button(action: {
                            selectedBands.removeAll()
                            viewModel.resetEQToDefault()
                        }) {
                            Text("FLAT")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(isFlatButtonPressed ? .black : Color(hex: "#ccffff")) // ← ここだけ変更！
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isFlatButtonPressed ? Color(hex: "#ccffff") : Color(hex: "#292b2a"))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(hex: "#202425"), lineWidth: 1)
                                )
                                .shadow(
                                    color: isFlatButtonPressed ? Color(hex: "#00FFFF").opacity(0.8) : .clear,
                                    radius: 10
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in isFlatButtonPressed = true }
                                .onEnded { _ in isFlatButtonPressed = false }
                        )
                        
                        // 録音・再生ボタン
                        VStack(spacing: 8) {
                            // 録音
                            Button(action: { isRecording.toggle() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isRecording ? Color(hex: "#d82c19") : Color(hex: "#292b2a")) // 背景色切り替え
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color(hex: "#202425"), lineWidth: 1)
                                        )
                                        .shadow(
                                            color: isRecording ? Color(hex: "#d82c19").opacity(0.8) : .clear,
                                            radius: isRecording ? 12 : 0
                                        )
                                    
                                    Image(systemName: "record.circle")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(Color(hex: "#ccffff")) // 常に同じ色
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 再生
                            Button(action: {
                                viewModel.togglePlayback()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(viewModel.playerNode.isPlaying ? Color(hex: "#d82c19") : Color(hex: "#292b2a")) // 背景切り替え
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color(hex: "#202425"), lineWidth: 1)
                                        )
                                        .shadow(
                                            color: viewModel.playerNode.isPlaying ? Color(hex: "#d82c19").opacity(0.8) : .clear,
                                            radius: viewModel.playerNode.isPlaying ? 12 : 0
                                        )
                                    
                                    Image(systemName: "play.fill")
                                        .resizable()
                                        .frame(width: 25, height: 25)
                                        .foregroundColor(Color(hex: "#ccffff")) // 常に同じ色
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                        }
                    }
                    .padding()
                    .frame(width: 80, height: contentHeight, alignment: .top)
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)
                    
                    // MARK: 中央：EQ + GAIN + LEVEL（幅拡張）
                    HStack(alignment: .top, spacing: 20) {
                        eqSlidersView(
                            sliderHeight: contentHeight * 0.66,
                            labelHeight: contentHeight * 0.2,
                            eqAreaWidth: geo.size.width * 0.65, // 幅を広げる
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
                    .padding(10)
                    .frame(height: contentHeight)
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)
                    
                    
                    
                    // MARK: 右：3カラム目全体
                    VStack(spacing: 8) {
                        
                        // 上部：Preset ラベル + Save / Load ボタンを囲む枠
                        VStack(spacing: 8) {
                            Text("Preset")
                                .padding(.top, 12)
                                .foregroundColor(Color(hex: "#ccffff"))
                                .font(.system(size: 14, weight: .bold))

                            // Save ボタン
                            Button(action: {
                                activeSheet = .savePreset
                            }) {
                                Text("SAVE")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(isSaveButtonPressed ? .black : Color(hex: "#ccffff"))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isSaveButtonPressed ? Color(hex: "#ccffff") : Color(hex: "#212224"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: isSaveButtonPressed ? Color(hex: "#ccffff").opacity(0.8) : .clear,
                                        radius: isSaveButtonPressed ? 10 : 0
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in isSaveButtonPressed = true }
                                    .onEnded { _ in isSaveButtonPressed = false }
                            )

                            // Load ボタン
                            Button(action: {
                                activeSheet = .loadPreset
                            }) {
                                Text("LOAD")
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(isLoadButtonPressed ? .black : Color(hex: "#ccffff"))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isLoadButtonPressed ? Color(hex: "#ccffff") : Color(hex: "#212224"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: isLoadButtonPressed ? Color(hex: "#ccffff").opacity(0.8) : .clear,
                                        radius: isLoadButtonPressed ? 10 : 0
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in isLoadButtonPressed = true }
                                    .onEnded { _ in isLoadButtonPressed = false }
                            )
                        }
                        .padding(8)
                        .background(Color(hex: "#19191b"))
                        .cornerRadius(8)

                        // 下部：Extra Panel（3ボタン入り）
                        VStack(spacing: 8) {
                            ForEach(["OPTION 1", "OPTION 2", "OPTION 3"], id: \.self) { label in
                                Button(action: {
                                    print("\(label) tapped") // ← 必要に応じてアクション追加
                                }) {
                                    Text(label)
                                        .font(.system(size: 16, weight: .heavy))
                                        .foregroundColor(Color(hex: "#ccffff"))
                                        .frame(width: 60, height: 60)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(hex: "#212224"))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color(hex: "#202425"), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }

                            Spacer() // 下に余白を残す
                        }
                        .padding(8)
                        .background(Color(hex: "#1e1e1e"))
                        .cornerRadius(8)


                    }
                    .frame(width: 65, height: contentHeight)

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
            thumbWidth: 50,
            thumbHeight: 30,
            trackColor: Color(hex: "#0f0f0f"),
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
                VStack(spacing: 4) {
                    let sliderBinding = Binding<Float>(
                        get: { viewModel.eqValues[index] },
                        set: { newValue in viewModel.updateEQ(at: index, value: newValue) }
                    )
                    
                    VStack(spacing: 4) {
                        // スライダー
                        defaultEQSlider(value: sliderBinding, range: -40...40)
                            .frame(width: 15, height: sliderHeight)
                        
                        // 周波数ラベル
                        Text(eqBands[index] >= 1000 ?
                             "\(eqBands[index]/1000, specifier: "%.1f") kHz" :
                                "\(Int(eqBands[index])) Hz")
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .frame(width: 60, height: labelHeight / 4)
                        .padding(.top, 10)
                        
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
        }
        .padding(.leading, 10) // ← ここで余白を加える
        .frame(width: eqAreaWidth - 10) // ← 全体の幅を調整して詰まりを防ぐ
    }


    // MARK: - GAIN
    private func gainSliderView(sliderHeight: CGFloat, labelHeight: CGFloat, gainSliderWidth: CGFloat) -> some View {
        VStack(spacing: 0.5) {
            defaultEQSlider(value: $viewModel.gain, range: 0...2)
                .frame(width: 15, height: sliderHeight)

            Text("Gain")
                .font(.system(size: 8))
                .foregroundColor(.white)
                .frame(width: 60, height: labelHeight / 4)
                .padding(.top, 10)

            Text(String(format: "%.2f", viewModel.gain))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 60, height: labelHeight / 4)
        }
        .frame(width: gainSliderWidth, height: sliderHeight + labelHeight, alignment: .top) // 揃え
        .padding(.leading, 20)
    }

    // MARK: - LEVEL
    private func levelMeterView(sliderHeight: CGFloat, labelHeight: CGFloat) -> some View {
        VStack(spacing: 0.5) {
            LevelMeterViewSwiftUI(level: viewModel.level)
                .frame(width: 20, height: sliderHeight)

            VStack(spacing: 2) {
                Text("Current Loudness")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .frame(width: 60, height: labelHeight / 4)
                    .padding(.top, 10)

                Text(String(format: "%.2f dB", viewModel.level))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 60, height: labelHeight / 4)
            }

        }
        .frame(height: sliderHeight + labelHeight, alignment: .top) // 上揃え
    }

}

