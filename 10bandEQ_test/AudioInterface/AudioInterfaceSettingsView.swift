import SwiftUI
import AVFoundation

struct AudioInterfaceSettingsView: View {
    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    @State private var selectedInput: AVAudioSessionPortDescription?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // カスタムヘッダー
            HStack {
                Text("Audio Settings")
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
            
            // 出力デバイス一覧表示（見出し＋リスト）
            VStack(alignment: .leading, spacing: 4) {
                Text("Output device")
                    .font(.system(size: 16, weight: .bold))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.bottom, 30)
                    .padding(.leading, 15)
                
                ForEach(currentOutputs, id: \.uid) { output in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(output.portName) // 例: "Sony WH-1000XM4"
                            .font(.system(size: 16)) // 本体名を16px
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text(portTypeDescription(output.portType)) // 例: "Bluetooth A2DP"
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 35)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading) // これを追加
            .padding(.top, 20)
            .padding(.horizontal) // 全体の左揃えとスペーシングに対してのみ適用
            
            
            // 入力デバイス一覧
            List {
                Section(header:
                            Text("Input device")
                    .font(.system(size: 16, weight: .bold)) // 見出し調整
                    .foregroundColor(.white)
                ) {
                    if availableInputs.isEmpty {
                        Text("No input available")
                            .foregroundColor(.white)
                    } else {
                        ForEach(availableInputs, id: \.uid) { input in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(input.portName)
                                        .font(.system(size: 16)) // 機器名調整
                                        .foregroundColor(.white)
                                    
                                    Text(isCurrentInput(input) ? "Selected" : "Not Selected")
                                        .font(.footnote)
                                        .foregroundColor(isCurrentInput(input) ? .green : .gray)
                                }
                                
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                setPreferredInput(input)
                            }
                            .padding()
                            .background(Color(hex: "#393d40"))
                            .cornerRadius(6)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            
            .listStyle(PlainListStyle())
            .background(Color(hex: "#393d40"))
            .scrollContentBackground(.hidden)
            .padding(.horizontal)
            
            // Updateボタン
            Button("Update") {
                loadDevices()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(hex: "#ccffff"))
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding()
            
            Spacer()
        }
        .background(Color(hex: "#393d40"))
        .onAppear {
            loadDevices()
            NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                loadDevices()
            }
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(title: Text("Error"),
                  message: Text(errorMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    private var currentOutputs: [AVAudioSessionPortDescription] {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.outputs
    }
    
    private func portTypeDescription(_ portType: AVAudioSession.Port) -> String {
        switch portType {
        case .builtInMic: return "Built-in Microphone"
        case .builtInSpeaker: return "Built-in Speaker"
        case .headphones: return "Wired Headphones"
        case .bluetoothA2DP: return "Bluetooth A2DP"
        case .bluetoothHFP: return "Bluetooth Hands-Free"
        case .usbAudio: return "USB Audio"
        case .carAudio: return "Car Audio"
        case .lineOut: return "Line Out"
        default: return portType.rawValue
        }
    }
    
    private func isCurrentInput(_ input: AVAudioSessionPortDescription) -> Bool {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.inputs.contains(where: { $0.uid == input.uid })
    }
    
    private func loadDevices() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
            
            availableInputs = session.availableInputs?.filter {
                $0.portType == .builtInMic ||
                $0.portType == .bluetoothHFP ||
                $0.portType == .usbAudio ||
                $0.portType == .carAudio
            } ?? []
            
            selectedInput = session.preferredInput
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func setPreferredInput(_ input: AVAudioSessionPortDescription) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredInput(input)
            try session.setActive(true)
            selectedInput = input
        } catch {
            errorMessage = "Failed to change input settings: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}
