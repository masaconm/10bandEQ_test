//
//  Untitled.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/04/13.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

//20250407 積み上げバーにグラデーションを追加
struct LevelMeterViewSwiftUI: View {
    var level: Float  // 現在の dB 値
    
    // しきい値と、それに対応するカラー（LED風に滑らか）
    let thresholds: [(lkfs: Float, color: Color)] = [
        (0, .red),
        (-3, .red),
        (-6, .orange),   // ← 赤からオレンジに変化
        (-9, .orange),
        (-18, .yellow),  // ← オレンジから黄色に変化
        (-23, .yellow),
        (-27, .green),   // ← 黄色から緑に変化
        (-36, .green),
        (-45, .green),
        (-54, .green),
        (-64, .green)
    ]
    
    
    var body: some View {
        GeometryReader { geo in
            let maxHeight = geo.size.height
            let sectionHeight = maxHeight / CGFloat(thresholds.count)
            
            VStack(spacing: 0) {
                ForEach(0..<thresholds.count, id: \.self) { i in
                    let current = thresholds[i]
                    let next = i < thresholds.count - 1 ? thresholds[i + 1] : current
                    
                    Rectangle()
                        .fill(
                            level > current.lkfs
                            ? (
                                current.color != next.color
                                ? AnyShapeStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [current.color, next.color]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                : AnyShapeStyle(current.color)
                            )
                            : AnyShapeStyle(Color.clear)
                        )
                        .frame(height: sectionHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .background(Color.black)
        }
    }
}
