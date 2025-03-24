//
//  View+Extensions.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/24.
//


import SwiftUI

extension View {
    func customBottomButton() -> some View {
        self
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#2a2e2f"))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(hex: "#202425"), lineWidth: 1)
            )
    }
}
