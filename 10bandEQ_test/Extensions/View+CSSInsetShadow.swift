//
//  View+CSSInsetShadow.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/23.
//

import SwiftUI

struct CSSInsetShadow: ViewModifier {
    var cornerRadius: CGFloat = 4
    var shadowColor: Color = .black
    var shadowRadius: CGFloat = 20
    var offsetY: CGFloat = 5
    var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .shadow(color: shadowColor.opacity(opacity),
                            radius: shadowRadius,
                            x: 0,
                            y: offsetY)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .compositingGroup()
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.black)
                    )
            )
    }
}

extension View {
    func cssInsetShadow(
        cornerRadius: CGFloat = 4,
        shadowColor: Color = .black,
        shadowRadius: CGFloat = 20,
        offsetY: CGFloat = 5,
        opacity: Double = 1.0
    ) -> some View {
        self.modifier(
            CSSInsetShadow(
                cornerRadius: cornerRadius,
                shadowColor: shadowColor,
                shadowRadius: shadowRadius,
                offsetY: offsetY,
                opacity: opacity
            )
        )
    }
}
