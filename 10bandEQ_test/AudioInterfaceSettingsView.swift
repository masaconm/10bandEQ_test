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
                    Section(header: Text("Input Device")) {
                        if availableInputs.isEmpty {
                            Text("No Input Available")
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
        availableInputs = session.availableInputs ?? []
        selectedInput = session.preferredInput
    }
    
    /// 指定された入力デバイスを優先入力として設定する
    private func setPreferredInput(_ input: AVAudioSessionPortDescription) {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredInput(input)
            selectedInput = input
        } catch {
            errorMessage = "Failed to change input settings: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
}

