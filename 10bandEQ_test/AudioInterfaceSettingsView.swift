import SwiftUI
import AVFoundation

struct AudioInterfaceSettingsView: View {
    @State private var availableInputs: [AVAudioSessionPortDescription] = []
    @State private var selectedInput: AVAudioSessionPortDescription?
    @State private var currentOutputs: [AVAudioSessionPortDescription] = []
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // 出力機器情報を表示（現在の出力ルート）
                Section(header: Text("Output Devices")) {
                    if currentOutputs.isEmpty {
                        Text("No active outputs")
                    } else {
                        ForEach(currentOutputs, id: \.uid) { output in
                            HStack {
                                Text(output.portName)
                                Spacer()
                                Text("Active")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                // 入力機器一覧を表示（利用可能な入力）
                Section(header: Text("Input Devices")) {
                    if availableInputs.isEmpty {
                        Text("No available inputs")
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
            .navigationTitle("Audio Interface Settings")
            .navigationBarItems(trailing: Button("Refresh") {
                loadDevices()
            })
            .onAppear {
                loadDevices()
            }
            .alert(isPresented: $showingErrorAlert) {
                Alert(title: Text("Error"),
                      message: Text(errorMessage),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
    
    /// 利用可能な入力・現在の出力情報を取得する
    private func loadDevices() {
        let session = AVAudioSession.sharedInstance()
        availableInputs = session.availableInputs ?? []
        selectedInput = session.preferredInput
        currentOutputs = session.currentRoute.outputs
    }
    
    /// タップされた入力を preferredInput として設定する
    private func setPreferredInput(_ input: AVAudioSessionPortDescription) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredInput(input)
            selectedInput = input
            print("Preferred input set to \(input.portName)")
        } catch {
            errorMessage = "Error setting preferred input: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

