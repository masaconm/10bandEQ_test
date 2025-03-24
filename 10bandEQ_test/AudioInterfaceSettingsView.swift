//AudioInterfaceSettingsView.swift

import SwiftUI
import AVFoundation

/// オーディオインターフェースの設定画面
struct AudioInterfaceSettingsView: View {
    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    @State private var selectedInput: AVAudioSessionPortDescription?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // 現在の出力デバイス名を表示
                Text("Current Output: \(currentOutputName)")
                    .font(.headline)
                    .padding()
                
                // 利用可能な入力デバイスの一覧を表示
                List {
                    Section(header: Text("Input device")) {
                        if availableInputs.isEmpty {
                            Text("No input available")
                        } else {
                            ForEach(availableInputs, id: \.uid) { input in
                                HStack {
                                    Text(input.portName)
                                    Spacer()
                                    if input == selectedInput {
                                        Text("Selected")
                                            .foregroundColor(.green)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    setPreferredInput(input)
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Audio Interface Settings")
            .navigationBarItems(trailing: Button("Update") {
                loadDevices()
            })
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
    }
    
    /// 現在の出力デバイス名を返す
    private var currentOutputName: String {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.outputs.first?.portName ?? "Unknown"
    }
    
    /// 利用可能な入力と現在の設定を取得する
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

    /// 指定された入力デバイスを優先入力として設定する
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

