//HeaderView.swift

import SwiftUI

struct HeaderView: View {
    let settingsAction: () -> Void

    var body: some View {
        HStack {
            // 左ロゴ
            Image("logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 50) // ✅ 高さを統一
                .padding(.leading, 10)

            Spacer()

            // 右：設定アイコン
            Button(action: settingsAction) {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 40) // ✅ 同じ高さ
                    .foregroundColor(Color(hex: "#ccffff"))
            }
            .padding(.trailing, 10)
        }
        .padding(.top, 25)
        .frame(height: 80)
        .background(Color(hex: "#1A1A1A"))
        .ignoresSafeArea(edges: .top)
    }
}
