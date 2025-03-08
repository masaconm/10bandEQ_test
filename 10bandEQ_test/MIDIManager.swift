/// MIDIManager.swift

import CoreMIDI

class MIDIManager {
    var client = MIDIClientRef()
    var inputPort = MIDIPortRef()
    
    /// 外部から MIDI メッセージを受け取るためのハンドラ
    var midiMessageHandler: (([UInt8]) -> Void)?
    
    init() {
        createMIDIClient()
        createInputPort()
        connectAllMIDISources()
    }
    
    private func createMIDIClient() {
        let status = MIDIClientCreate("MIDI Client" as CFString, nil, nil, &client)
        if status != noErr {
            print("Error creating MIDI client: \(status)")
        } else {
            print("MIDI client created.")
        }
    }
    
    private func createInputPort() {
        // MIDIInputPortCreate のコンテキストに self を渡す
        let status = MIDIInputPortCreate(client, "Input Port" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)
        if status != noErr {
            print("Error creating MIDI input port: \(status)")
        } else {
            print("MIDI input port created.")
        }
    }
    
    private func connectAllMIDISources() {
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let src = MIDIGetSource(i)
            let status = MIDIPortConnectSource(inputPort, src, nil)
            if status != noErr {
                print("Error connecting MIDI source at index \(i): \(status)")
            } else {
                print("Connected MIDI source at index \(i).")
            }
        }
    }
    
    /// MIDI 受信用コールバック
    private let midiReadProc: MIDIReadProc = { (packetList, readProcRefCon, srcConnRefCon) in
        // コンテキストから MIDIManager のインスタンスを取得
        let midiManagerInstance = Unmanaged<MIDIManager>.fromOpaque(readProcRefCon!).takeUnretainedValue()
        
        let packets = packetList.pointee
        var packet = packets.packet
        for _ in 0..<packets.numPackets {
            var midiBytes: [UInt8] = []
            // タプルを UnsafeRawPointer 経由で UInt8 配列として読み出す
            let dataPtr = UnsafeRawPointer(&packet.data).assumingMemoryBound(to: UInt8.self)
            for i in 0..<Int(packet.length) {
                midiBytes.append(dataPtr[i])
            }
            // 受信した MIDI メッセージがあれば、設定されたハンドラを呼び出す
            midiManagerInstance.midiMessageHandler?(midiBytes)
            
            packet = MIDIPacketNext(&packet).pointee
        }
    }
}

