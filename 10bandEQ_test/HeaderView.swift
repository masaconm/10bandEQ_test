//HeaderView.swift

import SwiftUI

/// HeaderView: Displays the logo and a left‐aligned Settings button.
/// (Language switching is handled in SettingsView.)
struct HeaderView: View {
    // Settings ボタンタップ時のアクション
    let settingsAction: () -> Void

    var body: some View {
        GeometryReader { geo in
            HStack {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .padding(.leading, 10)
                // Settings ボタンをロゴのすぐ右側に配置
                Button("Settings") {
                    settingsAction()
                }
                .frame(width: 120, height: 30)
                .background(Color.white)
                .cornerRadius(5)
                .padding(.leading, 10)
                Spacer()
            }
        }
        .frame(height: 60)
        .background(Color.gray)
    }
}

