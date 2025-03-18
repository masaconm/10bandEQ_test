//
//  MIDIMapping.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/08.
//

import Foundation

struct MIDIMapping: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var parameterName: String  // 例："EQ 32Hz", "EQ 64Hz", "GAIN" など
    // 未割当の場合は -1 などの値で管理
    var midiCC: Int
}

