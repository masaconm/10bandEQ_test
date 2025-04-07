//// EQContainerView.swift
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
    @State private var isPickerButtonPressed = false
    @State private var isPlaylistButtonPressed = false
    
    private var eqBands: [Float] {
        viewModel.eqBandsFrequencies
    }
    
    var body: some View {
        GeometryReader { geo in
            let contentHeight = geo.size.height * 0.9
            
            VStack(spacing: 10) {
                // MARK: - EQ & ボタン列（3列構成）
                HStack(alignment: .top, spacing: 10) {
                    // MARK: 左：操作ボタン列
                    VStack(spacing: 8) {
                        ForEach(["HI", "MID", "LOW"], id: \.self) { name in
                            let isSelected = selectedBands.contains(name)
                            
                            Button(action: {
                                if isSelected {
                                    selectedBands.remove(name)
                                } else {
                                    selectedBands.insert(name)
                                }
                                
                                viewModel.applySelectedBands(
                                    low: selectedBands.contains("LOW"),
                                    mid: selectedBands.contains("MID"),
                                    high: selectedBands.contains("HI")
                                )
                            }) {
                                Text(name)
                                    .font(.system(size: 16, weight: .heavy))
                                    .foregroundColor(isSelected ? .black : Color(hex: "#ccffff"))
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
                                .foregroundColor(isFlatButtonPressed ? .black : Color(hex: "#ccffff"))
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
                        
                        // 再生
                        Button(action: {
                            viewModel.togglePlayback()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(viewModel.playerNode.isPlaying ? Color(hex: "#d82c19") : Color(hex: "#292b2a"))
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
                                    .foregroundColor(Color(hex: "#ccffff"))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.isLoadingWaveform || viewModel.sampleBuffer == nil)
                    }
                    .padding()
                    .frame(width: 80, height: contentHeight, alignment: .top)
                    .background(Color(hex: "#19191b"))
                    .cornerRadius(8)
                    .padding(.trailing, 10)
                    
                    // MARK: 中央：EQ + GAIN + LEVEL（幅拡張）
                    HStack(alignment: .top, spacing: 20) {
                        eqSlidersView(
                            sliderHeight: contentHeight * 0.66,
                            labelHeight: contentHeight * 0.2,
                            eqAreaWidth: geo.size.width * 0.65,
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
                    
                    // MARK: 右カラム（Preset + Extra Panel）
                    VStack(spacing: 8) {
                        // Preset枠
                        VStack(spacing: 8) {
                            Text("EQ Set")
                                .padding(.top, 12)
                                .foregroundColor(.white)
                                .font(.system(size: 12, weight: .bold))
                            
                            // SAVE
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
                            
                            // LOAD
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
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#19191b"))
                        .cornerRadius(8)
                        
                        // Extra Panel 枠
                        VStack(spacing: 8) {
                            // Select Audio File
                            Button(action: {
                                activeSheet = .picker
                            }) {
                                Image("list_icon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(isPickerButtonPressed ? .black : Color(hex: "#ccffff"))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isPickerButtonPressed ? Color(hex: "#ccffff") : Color(hex: "#212224"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: isPickerButtonPressed ? Color(hex: "#ccffff").opacity(0.8) : .clear,
                                        radius: isPickerButtonPressed ? 10 : 0
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in isPickerButtonPressed = true }
                                    .onEnded { _ in isPickerButtonPressed = false }
                            )
                            
                            // Playlist ボタン
                            Button(action: {
                                activeSheet = .playlist
                            }) {
                                Image("select_music")
                                    .resizable()
                                    .renderingMode(.template)
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(isPlaylistButtonPressed ? .black : Color(hex: "#ccffff"))
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isPlaylistButtonPressed ? Color(hex: "#ccffff") : Color(hex: "#212224"))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(hex: "#202425"), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: isPlaylistButtonPressed ? Color(hex: "#ccffff").opacity(0.8) : .clear,
                                        radius: isPlaylistButtonPressed ? 10 : 0
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in isPlaylistButtonPressed = true }
                                    .onEnded { _ in isPlaylistButtonPressed = false }
                            )
                            
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#19191b"))
                        .cornerRadius(8)
                    }
                    .frame(width: 65, height: contentHeight)
                    .padding(.leading, 15)
                }
            }
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
    // MARK: - GAINスライダー
    private func gainEQSlider(value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        CustomVerticalSlider(
            value: value,
            range: range,
            thumbWidth: 50,
            thumbHeight: 30,
            trackColor: Color(hex: "#0f0f0f"),
            fillColor: Color(hex: "#A6FFFF"), // GAIN用は別の色
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
                    .frame(alignment: .top)
                }
            }
        }
        .padding(.leading, 10)
        .frame(width: eqAreaWidth - 10)
    }
    
    // MARK: - GAIN
    private func gainSliderView(sliderHeight: CGFloat, labelHeight: CGFloat, gainSliderWidth: CGFloat) -> some View {
        VStack(spacing: 0.5) {
            gainEQSlider(value: $viewModel.gain, range: 0...2)
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
        .frame(width: gainSliderWidth, height: sliderHeight + labelHeight, alignment: .top)
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
        .frame(height: sliderHeight + labelHeight, alignment: .top)
    }
}
