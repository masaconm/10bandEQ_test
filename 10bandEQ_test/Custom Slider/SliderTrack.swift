//
//  SliderTrack.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/23.
//

import SwiftUI

struct SliderTrack: View {
    var percentage: CGFloat       // 塗りの高さ（現在のスライダー値）
    var width: CGFloat            // トラックの横幅
    var height: CGFloat           // ✅ トラック全体の高さ（追加）
    var trackColor: Color = .black
    var fillColor: Color = .blue
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // トラック背景
            RoundedRectangle(cornerRadius: 4)
                .fill(trackColor)
                .frame(width: width, height: height)  // ✅ 高さ指定追加
                .cssInsetShadow(
                    cornerRadius: 4,
                    shadowColor: .black,
                    shadowRadius: 20,
                    offsetY: 5,
                    opacity: 1.0
                )
            
            // 塗り（値に応じて変化）
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .shadow(color: fillColor.opacity(0.8), radius: 10)
                .frame(width: width, height: percentage)
        }
        .frame(width: width, height: height) // ✅ 外枠も高さ指定
    }
}
