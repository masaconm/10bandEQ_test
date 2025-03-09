//
//  LanguageSettingsView.swift
//  10bandEQ_test
//
//  Created by 中静暢子 on 2025/03/09.
//

import SwiftUI

/// LanguageSettingsView: A simple view to switch the app's language.
struct LanguageSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Select Language")
                .font(.headline)
            Button("English") {
                // 英語に設定する処理をここに実装
                print("Language set to English")
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
            
            Button("Japanese") {
                // 日本語に設定する処理をここに実装
                print("Language set to Japanese")
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}
