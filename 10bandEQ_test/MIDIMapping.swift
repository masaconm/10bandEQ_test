//
//  MIDIMapping.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/08.

import Foundation

/// アプリ内パラメーターと MIDI CC 番号の対応情報を保持するモデル
struct MIDIMapping: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var parameterName: String  // 例: "EQ 32Hz", "EQ 64Hz", "GAIN" など
    var midiCC: Int            // 割り当てられている MIDI CC 番号
}
