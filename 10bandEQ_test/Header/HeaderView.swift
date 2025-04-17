import SwiftUI

struct HeaderView: View {
    let settingsAction: () -> Void
    let midiMappingAction: () -> Void
    let recordingToggleAction: () -> Void
    let isRecording: Bool
    @ObservedObject var audioEngineManager: AudioEngineManager

    var body: some View {
        let topPadding = safeAreaTopInset()

        ZStack(alignment: .bottom) {
            Color(hex: "#1A1A1A")

            HStack(alignment: .bottom) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40)
                    .padding(.leading, 10)

                Spacer()

                // 🔴 録音トグルボタン
                HStack(spacing: 8) {
                    Button(action: recordingToggleAction) {
<<<<<<< HEAD
                        Text(isRecording ? "Stop Recording" : "Recording")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 140, height: 30)
                            .background(isRecording ? Color.red : Color(hex: "#333333"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    if isRecording {
                        Text(timeString(from: audioEngineManager.recordingTime))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white)
                            .frame(height: 30)
                    }
                }
                .padding(.trailing, 8)

=======
                        Text(isRecording ? "Exit Recording Mode" : "Enter Recording Mode")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 180, height: 30)
                            .background(Color(hex: "#333333"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.trailing, 8)


>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
                Button("MIDI Mapping", action: midiMappingAction)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200, height: 30)
                    .background(Color(hex: "#333333"))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.trailing, 12)

                Button(action: settingsAction) {
                    Image(systemName: "gearshape.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(Color(hex: "#ccffff"))
                }
                .padding(.trailing, 10)
            }
            .padding(.top, topPadding)
            .padding(.bottom, 5)
        }
<<<<<<< HEAD
=======
        .zIndex(1) // ← Overviewエリア（録音中赤背景）より後ろに配置
>>>>>>> 225a73d (20250417 Recodeing Modeへ遷移後のモニタリングモードと録音機能、録音音声のwavとmp3でのDL機能を追加、関連するUI調整をしました)
    }

    private func safeAreaTopInset() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 20
    }

    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

