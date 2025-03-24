//
//  SliderTrack.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/23.
//

import SwiftUI

struct SliderTrack: View {
    var percentage: CGFloat       // 充填部分の高さ（スライダーの値に基づく）
    var width: CGFloat            // トラックの横幅
    var trackColor: Color = .black
    var fillColor: Color = .blue

    var body: some View {
        ZStack(alignment: .bottom) {
            // トラック背景（暗いグレー + inset shadow）
            RoundedRectangle(cornerRadius: 4)
                .fill(trackColor)
                .frame(width: width)
                .cssInsetShadow(
                    cornerRadius: 4,
                    shadowColor: .black,
                    shadowRadius: 20,
                    offsetY: 5,
                    opacity: 1.0
                )

            // 塗り（fillColor）＋ グロー効果
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .shadow(color: fillColor.opacity(0.8), radius: 10, x: 0, y: 0) // グロー（光）
                .frame(width: width, height: percentage)
        }
        .frame(width: width)
    }
}
