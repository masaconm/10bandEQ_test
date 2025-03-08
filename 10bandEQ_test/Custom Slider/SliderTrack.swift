//
//  Untitled.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/03.
//
import SwiftUI
struct SliderTrack: View {
    var percentage: CGFloat       // 充填部分の高さ（スライダーの値に基づく）
    var width: CGFloat            // トラックの横幅
    var trackColor: Color = .gray
    var fillColor: Color = .blue
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(trackColor)
                .frame(width: width)
            Rectangle()
                .fill(fillColor)
                .frame(width: width, height: percentage)
        }
    }
}
