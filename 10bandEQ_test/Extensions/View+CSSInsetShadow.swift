//
//  View+CSSInsetShadow.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/23.
//

import SwiftUI

// MARK: - CSS風 内側シャドウ用 ViewModifier
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

// MARK: - View 拡張（テキスト系ボタンなどに使う）
extension View {
    /// CSS Inset Shadow 修飾
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
    
    /// Preset / Extra Panel 用の共通テキストボタンスタイル
    func presetStyleButton() -> some View {
        self
            .font(.system(size: 16, weight: .heavy))
            .foregroundColor(Color(hex: "#ccffff"))
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#212224"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "#202425"), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Image 拡張（画像アイコンボタン用）
extension Image {
    /// アイコン画像ボタンの共通スタイル
    func presetStyleImageButton() -> some View {
        self
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .frame(width: 60, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "#212224"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(hex: "#202425"), lineWidth: 1)
            )
            .buttonStyle(PlainButtonStyle())
    }
}
